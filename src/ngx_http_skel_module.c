/*
 * Copyright (C) 2026 Thijs Eilander
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * ngx_http_skel_module -- skeleton nginx dynamic HTTP module.
 *
 * A minimal but COMPLETE module: merged loc conf with the three-state
 * (unset/off/on) enable flag, a bounded scan over the URI + one header, an
 * optional request-body scan, and a PRECONTENT-phase handler.
 *
 * The scan core lives in ngx_http_skel_scan.c and takes plain (u_char *, len)
 * buffers with no ngx_http_request_t in sight, so ci/fuzz/fuzz_scan.c can drive
 * the exact production code the handler runs.
 *
 * PRECONTENT, not ACCESS/REWRITE: the body is only available after the phase
 * engine has run the preceding phases, and a handler that wants to inspect a
 * body must be able to return NGX_AGAIN and be re-entered. `return`-style
 * directives finalize in REWRITE, before PRECONTENT -- so a test location must
 * use a real content handler (empty_gif) or the handler never runs.
 */

#include <ngx_config.h>
#include <ngx_core.h>
#include <ngx_http.h>

#include "ngx_http_skel_scan.h"


typedef struct {
    ngx_uint_t   mode;        /* NGX_HTTP_SKEL_MODE_*                        */
    ngx_uint_t   status;      /* status to return in block mode              */
    size_t       max_body;    /* bytes of body to scan; 0 disables the scan  */
} ngx_http_skel_loc_conf_t;


/*
 * Presence of the ctx means "we already asked for the body". The phase engine
 * re-enters the handler after the body read completes, and on that pass the
 * handler just returns the verdict the body handler recorded here.
 */
typedef struct {
    ngx_int_t    status;      /* verdict from the body pass; NGX_DECLINED = pass */
} ngx_http_skel_ctx_t;


static ngx_int_t ngx_http_skel_handler(ngx_http_request_t *r);
static void ngx_http_skel_body_handler(ngx_http_request_t *r);
static ngx_int_t ngx_http_skel_inspect(ngx_http_request_t *r,
    ngx_http_skel_loc_conf_t *slcf);
static ngx_int_t ngx_http_skel_scan_body(ngx_http_request_t *r, size_t max);
static void ngx_http_skel_log_match(ngx_http_request_t *r,
    ngx_http_skel_loc_conf_t *slcf);

static void *ngx_http_skel_create_loc_conf(ngx_conf_t *cf);
static char *ngx_http_skel_merge_loc_conf(ngx_conf_t *cf, void *parent,
    void *child);
static ngx_int_t ngx_http_skel_init(ngx_conf_t *cf);


static ngx_conf_enum_t  ngx_http_skel_modes[] = {
    { ngx_string("off"),    NGX_HTTP_SKEL_MODE_OFF    },
    { ngx_string("detect"), NGX_HTTP_SKEL_MODE_DETECT },
    { ngx_string("block"),  NGX_HTTP_SKEL_MODE_BLOCK  },
    { ngx_null_string, 0 }
};

/*
 * Constrained on purpose: an arbitrary status here lets a config typo turn a
 * block into a 200. Only codes that make sense as a refusal are accepted.
 */
static ngx_conf_enum_t  ngx_http_skel_statuses[] = {
    { ngx_string("403"), NGX_HTTP_FORBIDDEN            },
    { ngx_string("404"), NGX_HTTP_NOT_FOUND            },
    { ngx_string("429"), NGX_HTTP_TOO_MANY_REQUESTS    },
    { ngx_string("444"), NGX_HTTP_CLOSE                },
    { ngx_null_string, 0 }
};


static ngx_command_t  ngx_http_skel_commands[] = {

    { ngx_string("skel"),
      NGX_HTTP_MAIN_CONF|NGX_HTTP_SRV_CONF|NGX_HTTP_LOC_CONF|NGX_CONF_TAKE1,
      ngx_conf_set_enum_slot,
      NGX_HTTP_LOC_CONF_OFFSET,
      offsetof(ngx_http_skel_loc_conf_t, mode),
      &ngx_http_skel_modes },

    { ngx_string("skel_status"),
      NGX_HTTP_MAIN_CONF|NGX_HTTP_SRV_CONF|NGX_HTTP_LOC_CONF|NGX_CONF_TAKE1,
      ngx_conf_set_enum_slot,
      NGX_HTTP_LOC_CONF_OFFSET,
      offsetof(ngx_http_skel_loc_conf_t, status),
      &ngx_http_skel_statuses },

    { ngx_string("skel_max_body"),
      NGX_HTTP_MAIN_CONF|NGX_HTTP_SRV_CONF|NGX_HTTP_LOC_CONF|NGX_CONF_TAKE1,
      ngx_conf_set_size_slot,
      NGX_HTTP_LOC_CONF_OFFSET,
      offsetof(ngx_http_skel_loc_conf_t, max_body),
      NULL },

      ngx_null_command
};


static ngx_http_module_t  ngx_http_skel_module_ctx = {
    NULL,                             /* preconfiguration                    */
    ngx_http_skel_init,               /* postconfiguration                   */

    NULL,                             /* create main configuration           */
    NULL,                             /* init main configuration             */

    NULL,                             /* create server configuration         */
    NULL,                             /* merge server configuration          */

    ngx_http_skel_create_loc_conf,    /* create location configuration       */
    ngx_http_skel_merge_loc_conf      /* merge location configuration        */
};


ngx_module_t  ngx_http_skel_module = {
    NGX_MODULE_V1,
    &ngx_http_skel_module_ctx,        /* module context                      */
    ngx_http_skel_commands,           /* module directives                   */
    NGX_HTTP_MODULE,                  /* module type                         */
    NULL,                             /* init master                         */
    NULL,                             /* init module                         */
    NULL,                             /* init process                        */
    NULL,                             /* init thread                         */
    NULL,                             /* exit thread                         */
    NULL,                             /* exit process                        */
    NULL,                             /* exit master                         */
    NGX_MODULE_V1_PADDING
};


static ngx_int_t
ngx_http_skel_handler(ngx_http_request_t *r)
{
    ngx_int_t                  rc;
    ngx_http_skel_ctx_t       *ctx;
    ngx_http_skel_loc_conf_t  *slcf;

    /* Subrequests inherit the parent's verdict; scanning them again would
     * double-count and can re-read a body that is no longer ours to consume. */
    if (r != r->main) {
        return NGX_DECLINED;
    }

    slcf = ngx_http_get_module_loc_conf(r, ngx_http_skel_module);

    if (slcf->mode == NGX_HTTP_SKEL_MODE_OFF) {
        return NGX_DECLINED;
    }

    /* Re-entry after the body read: the body handler already recorded the
     * verdict, so just return it. A ctx exists only on this second pass. */
    ctx = ngx_http_get_module_ctx(r, ngx_http_skel_module);
    if (ctx != NULL) {
        return ctx->status;
    }

    /* First pass: the request line and headers, no body. */
    rc = ngx_http_skel_inspect(r, slcf);
    if (rc != NGX_DECLINED) {
        return rc;
    }

    /*
     * Clean so far. Read and scan the body, if enabled and one can exist.
     *
     * Gate on body PRESENCE, not method: HTTP permits a body on any method
     * (DELETE included), and a method allowlist here is a policy bypass --
     * an attacker just picks a method outside the list. content_length_n > 0
     * covers fixed-length bodies; chunked bodies have no length up front, so
     * headers_in.chunked is the other indicator.
     */
    if (slcf->max_body == 0
        || (r->headers_in.content_length_n <= 0 && !r->headers_in.chunked))
    {
        return NGX_DECLINED;
    }

    ctx = ngx_pcalloc(r->pool, sizeof(ngx_http_skel_ctx_t));
    if (ctx == NULL) {
        return NGX_ERROR;
    }
    ctx->status = NGX_DECLINED;
    ngx_http_set_ctx(r, ctx, ngx_http_skel_module);

    /*
     * COST NOTE (by design, but know it): ngx_http_read_client_request_body()
     * reads and buffers the WHOLE body before the handler resumes -- in memory
     * up to client_body_buffer_size, then spooled to a temp file. The bound is
     * client_max_body_size, NOT skel_max_body: we inspect only the first
     * skel_max_body bytes, but nginx still buffers everything first. So enabling
     * the body scan (a) defeats request streaming (proxy_request_buffering off)
     * and (b) makes every upload up to client_max_body_size hit disk. Keep
     * client_max_body_size sane on body-scanned routes; do not read this as a
     * reason to raise skel_max_body -- that only widens the inspected prefix.
     */
    rc = ngx_http_read_client_request_body(r, ngx_http_skel_body_handler);
    if (rc >= NGX_HTTP_SPECIAL_RESPONSE) {
        return rc;
    }

    /*
     * NGX_DONE, and finalize with NGX_DONE first.
     *
     * read_client_request_body() took a reference on the request (r->count++).
     * ngx_http_finalize_request(r, NGX_DONE) drops exactly that reference
     * without finalizing, and returning NGX_DONE parks the phase engine until
     * the body handler restarts it. Hand-rolling this as `r->main->count--`
     * instead is what produces the "header already sent" alert on every POST:
     * the engine falls through to the content handler on THIS pass while the
     * body read is still pending, and then runs it a second time on resume.
     */
    ngx_http_finalize_request(r, NGX_DONE);

    return NGX_DONE;
}


static void
ngx_http_skel_body_handler(ngx_http_request_t *r)
{
    ngx_http_skel_ctx_t       *ctx;
    ngx_http_skel_loc_conf_t  *slcf;

    ctx = ngx_http_get_module_ctx(r, ngx_http_skel_module);
    slcf = ngx_http_get_module_loc_conf(r, ngx_http_skel_module);

    if (ngx_http_skel_scan_body(r, slcf->max_body) == NGX_HTTP_SKEL_CLEAN) {
        ctx->status = NGX_DECLINED;

    } else {
        ngx_http_skel_log_match(r, slcf);

        ctx->status = (slcf->mode == NGX_HTTP_SKEL_MODE_BLOCK)
                          ? (ngx_int_t) slcf->status
                          : NGX_DECLINED;
    }

    /* preserve_body: the content handler (proxy_pass, a POST target) still needs
     * the bytes we just buffered; without this they are discarded and it sees an
     * empty body. write_event_handler: the resume point once the engine parks. */
    r->preserve_body = 1;
    r->write_event_handler = ngx_http_core_run_phases;

    ngx_http_core_run_phases(r);
}


/*
 * Log at DEBUG (only, never a verdict change) when a field handed to a
 * single-shot ngx_http_skel_scan() call exceeds NGX_HTTP_SKEL_SCAN_MAX. The
 * scan core itself never logs (see ci/fuzz/ngx_stubs.c -- it must stay
 * allocation/log-free to link directly against nginx's real ngx_string.c),
 * so the caller checks the same public cap and logs here instead. This makes
 * the truncation observable in a debug build without touching the scan core.
 */
static void
ngx_http_skel_log_if_truncated(ngx_http_request_t *r, const char *field,
    size_t len)
{
#if (NGX_DEBUG)
    if (len > NGX_HTTP_SKEL_SCAN_MAX) {
        ngx_log_debug2(NGX_LOG_DEBUG_HTTP, r->connection->log, 0,
                       "skel: %s (%uz bytes) exceeds the %d-byte scan cap; "
                       "truncated, bytes past the cap are not inspected",
                       field, len, (int) NGX_HTTP_SKEL_SCAN_MAX);
    }
#else
    (void) r; (void) field; (void) len;
#endif
}


/* Scan the request line and headers. Returns the phase-handler verdict. */
static ngx_int_t
ngx_http_skel_inspect(ngx_http_request_t *r, ngx_http_skel_loc_conf_t *slcf)
{
    ngx_int_t         rc;
    ngx_table_elt_t  *ua;

    /* URI + args as they arrived on the wire (unparsed_uri covers both). */
    ngx_http_skel_log_if_truncated(r, "URI", r->unparsed_uri.len);
    rc = ngx_http_skel_scan(r->unparsed_uri.data, r->unparsed_uri.len);

    /*
     * User-Agent is a REPEATABLE header: a client may send it more than once.
     * Modern nginx (>=1.23) keeps only the FIRST line in headers_in.user_agent
     * and links the rest through ngx_table_elt_t.next. Scanning just the first
     * is a trivial bypass -- an attacker puts the payload in a SECOND
     * User-Agent line, which nginx still forwards upstream. Walk the whole
     * chain. RULE for any module cloned from this skeleton: a repeatable header
     * (User-Agent, X-Forwarded-For, Via, Forwarded, Cookie, ...) must be
     * scanned across its ->next chain, never just headers_in.<field>.
     */
    for (ua = r->headers_in.user_agent;
         ua != NULL && rc == NGX_HTTP_SKEL_CLEAN;
         ua = ua->next)
    {
        ngx_http_skel_log_if_truncated(r, "User-Agent", ua->value.len);
        rc = ngx_http_skel_scan(ua->value.data, ua->value.len);
    }

    if (rc == NGX_HTTP_SKEL_CLEAN) {
        return NGX_DECLINED;
    }

    ngx_http_skel_log_match(r, slcf);

    if (slcf->mode == NGX_HTTP_SKEL_MODE_DETECT) {
        return NGX_DECLINED;
    }

    return (ngx_int_t) slcf->status;
}


/*
 * Log the match. Only the verdict and the client are logged, never the matched
 * bytes: those are attacker-controlled and can carry control characters, so
 * echoing them into the error log is a log-injection primitive.
 */
static void
ngx_http_skel_log_match(ngx_http_request_t *r,
    ngx_http_skel_loc_conf_t *slcf)
{
    ngx_log_error(NGX_LOG_WARN, r->connection->log, 0,
                  "skel: match from %V, %s", &r->connection->addr_text,
                  slcf->mode == NGX_HTTP_SKEL_MODE_BLOCK
                      ? "blocked" : "detect only");
}


/*
 * Scan at most `max` bytes of the request body, in-memory chain plus (if the
 * body spilled to disk) the spooled temp file, with a carried tail so a rule
 * split across two chain buffers or across a chain/file seam is still caught
 * (F2). A body larger than max is scanned only up to max and then PASSES --
 * never blocked for being big; refusing large uploads because we could not
 * fully inspect them would make the module an availability hazard on any
 * file-upload route. That is an explicit, bounded truncation, not a silent
 * "clean" verdict over unread bytes: everything up to max IS read, in-memory
 * chain and spooled file alike.
 */
static ngx_int_t
ngx_http_skel_scan_body(ngx_http_request_t *r, size_t max)
{
    u_char        filebuf[4096];
    size_t        len, scanned;
    ssize_t       n;
    off_t         offset;
    ngx_int_t     rc;
    ngx_buf_t    *b;
    ngx_chain_t  *cl;
    ngx_temp_file_t *tf;
    ngx_http_skel_stream_t  st;

    if (r->request_body == NULL || r->request_body->bufs == NULL) {
        return NGX_HTTP_SKEL_CLEAN;
    }

    scanned = 0;
    ngx_memzero(&st, sizeof(st));

    for (cl = r->request_body->bufs; cl && scanned < max; cl = cl->next) {
        b = cl->buf;

        if (ngx_buf_special(b)) {
            continue;
        }

        if (b->in_file) {
            /*
             * Spooled to disk (client_body_in_file_only, or the buffered
             * body exceeded client_body_buffer_size). request_body->temp_file
             * holds the file; read it directly with ngx_read_file rather than
             * silently treating "no in-memory range" as "nothing to scan" --
             * that used to be an unconditional bypass (an attacker just had to
             * make the body spool). Read sequentially from the start of the
             * file each time we hit an in_file link; nginx may emit several
             * in_file buf links covering different file offsets, but for the
             * single-file body this module supports, scanning from file
             * offset 0 up to `max` once is sufficient and idempotent, so
             * later in_file links are skipped once we've read the file.
             */
            tf = r->request_body->temp_file;
            if (tf == NULL || tf->file.fd == NGX_INVALID_FILE) {
                continue;
            }
            offset = 0;

            while ((size_t) offset < max) {
                len = sizeof(filebuf);
                if ((size_t) offset + len > max) {
                    len = max - (size_t) offset;
                }

                n = ngx_read_file(&tf->file, filebuf, len, offset);
                if (n <= 0) {
                    break;
                }

                rc = ngx_http_skel_scan_piece(&st, filebuf, (size_t) n);
                if (rc != NGX_HTTP_SKEL_CLEAN) {
                    return rc;
                }

                scanned += (size_t) n;
                offset += n;

                if ((size_t) n < len) {
                    /* short read: end of file */
                    break;
                }
            }

            /* One pass over the temp file covers every in_file link that
             * points at it; skip the rest of the chain. */
            break;
        }

        if (b->last <= b->pos) {
            continue;
        }

        len = (size_t) (b->last - b->pos);

        if (scanned + len > max) {
            len = max - scanned;
        }

        rc = ngx_http_skel_scan_piece(&st, b->pos, len);
        if (rc != NGX_HTTP_SKEL_CLEAN) {
            return rc;
        }

        scanned += len;
    }

    /* End of the (bounded) body: flush any escape held mid-token at the seam. */
    return ngx_http_skel_stream_final(&st);
}


static void *
ngx_http_skel_create_loc_conf(ngx_conf_t *cf)
{
    ngx_http_skel_loc_conf_t  *conf;

    conf = ngx_pcalloc(cf->pool, sizeof(ngx_http_skel_loc_conf_t));
    if (conf == NULL) {
        return NULL;
    }

    conf->mode = NGX_CONF_UNSET_UINT;
    conf->status = NGX_CONF_UNSET_UINT;
    conf->max_body = NGX_CONF_UNSET_SIZE;

    return conf;
}


static char *
ngx_http_skel_merge_loc_conf(ngx_conf_t *cf, void *parent, void *child)
{
    ngx_http_skel_loc_conf_t *prev = parent;
    ngx_http_skel_loc_conf_t *conf = child;

    ngx_conf_merge_uint_value(conf->mode, prev->mode,
                              NGX_HTTP_SKEL_MODE_OFF);
    ngx_conf_merge_uint_value(conf->status, prev->status,
                              NGX_HTTP_FORBIDDEN);
    ngx_conf_merge_size_value(conf->max_body, prev->max_body, 8192);

    return NGX_CONF_OK;
}


static ngx_int_t
ngx_http_skel_init(ngx_conf_t *cf)
{
    ngx_http_handler_pt        *h;
    ngx_http_core_main_conf_t  *cmcf;

    /*
     * Fail loudly at config load if a rule is too long for the cross-buffer
     * seam carry (see NGX_HTTP_SKEL_MAX_RULE_LEN). Cheap, once, and it turns a
     * silent boundary-straddle bypass in a derived module into an obvious
     * startup error instead.
     */
    if (ngx_http_skel_scan_rules_valid() != NGX_OK) {
        ngx_log_error(NGX_LOG_EMERG, cf->log, 0,
                      "skel: a scan rule is too long for the %d-byte "
                      "cross-buffer seam carry; raise NGX_HTTP_SKEL_MAX_RULE_LEN "
                      "so that 3 * longest_rule < it",
                      (int) NGX_HTTP_SKEL_MAX_RULE_LEN);
        return NGX_ERROR;
    }

    cmcf = ngx_http_conf_get_module_main_conf(cf, ngx_http_core_module);

    h = ngx_array_push(&cmcf->phases[NGX_HTTP_PRECONTENT_PHASE].handlers);
    if (h == NULL) {
        return NGX_ERROR;
    }

    *h = ngx_http_skel_handler;

    return NGX_OK;
}
