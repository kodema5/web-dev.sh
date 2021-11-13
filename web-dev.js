// deno run --allow-read --allow-net web-dev.js

// https://deno.land/x/dotenv@v3.0.0
import { config } from "https://deno.land/x/dotenv/mod.ts"
config()

// https://deno.land/x/postgres@v0.13.0
import { Pool } from "https://deno.land/x/postgres/mod.ts"
const pool = new Pool ({
    hostname: config.PGHOST || 'localhost',
    port: config.PGPORT || 5432,
    user: config.PGUSER || 'web',
    password: config.PGPASSWORD || 'rei',
    database: config.PGDATABASE || 'web',
}, 10, true)


async function query(sql, arg) {
    try {
        const client = await pool.connect()
        let data
        try {
            let rs = await client.queryArray(sql, arg)
            data = rs.rows && rs.rows[0] && rs.rows[0][0]
        } finally {
            client.release()
        }
        return {data}
    } catch(e) {
        let n = e.name
        let error = n ==='ConnectionRefused' ? 'error.database_not_available' :
            n==='PostgresError' ? e.fields.message :
            e
        return {error}
    }
}

// https://deno.land/x/oak@v2.4.0
import { Application, Router, Status } from "https://deno.land/x/oak/mod.ts"
import { join, fromFileUrl, dirname } from "https://deno.land/std@0.110.0/path/mod.ts"

;(async () => {

    const router = new Router();
    router
        .get("/web.js", async ({response}) => {
            let p = dirname(fromFileUrl(import.meta.url))
            let a = await Deno.readTextFile(join(p, 'web.js'))
            response.body = a
            response.headers.set('content-type', 'text/javascript')
            response.headers.set('content-length', a.length)
        })
        .get("/api/:schema/:funcs+", async (ctx) => {
            let { schema, funcs } = ctx.params
            let func = funcs.replaceAll('/', '_')
            let req = ctx.request
            let arg = {
                origin: ctx.ip,
                authorization: req.headers.get('authorization'),
                namespace: req.headers.get('namespace'),
                ...(Object.fromEntries(new URLSearchParams(req.url.search))),
            }

            ctx.response.body = await query(`select ${schema}.web_${func} ($1::jsonb)`, arg)
        })
        .post("/api/:schema/:funcs+", async (ctx) => {
            let { schema, funcs } = ctx.params
            let func = funcs.replaceAll('/', '_')
            let req = ctx.request
            let arg = {
                origin: ctx.ip,
                authorization: req.headers.get('authorization'),
                namespace: req.headers.get('namespace'),
                ...(Object.fromEntries(new URLSearchParams(req.url.search))),
                ...(req.hasBody && await req.body().value),
            }

            ctx.response.body = await query(`select ${schema}.web_${func} ($1::jsonb)`, arg)
        })


    const app = new Application()
    app.use(router.routes())
    app.use(router.allowedMethods())
    app.use(async (ctx, next) => {
        let root = `${Deno.cwd()}`
        try {
            await ctx.send({ root, index:'index.html' })
        } catch {
            next()
        }
    })
    app.use( async ctx => {
        ctx.response.status = Status.NotFound
        ctx.response.body = `"${ctx.request.url}" not found`
    })

    console.log(`web-dev.js serving ${Deno.cwd()} at 8000`)
    await app.listen("127.0.0.1:8000")
})()