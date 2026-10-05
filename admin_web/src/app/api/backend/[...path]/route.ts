import { NextRequest, NextResponse } from "next/server";
import { cookies } from "next/headers";
import { ADMIN_COOKIE, backendUrl } from "@/lib/session";

/** Njia za backend zinazoruhusiwa kupitia proxy hii */
const ALLOWED_ROOTS = new Set(["admin", "verification-documents"]);

async function proxy(req: NextRequest, ctx: { params: Promise<{ path: string[] }> }) {
  const { path } = await ctx.params;
  if (!path?.length || !ALLOWED_ROOTS.has(path[0])) {
    return NextResponse.json({ success: false, message: "Njia hairuhusiwi" }, { status: 404 });
  }

  const token = (await cookies()).get(ADMIN_COOKIE)?.value;
  if (!token) {
    return NextResponse.json({ success: false, message: "Ingia kwanza" }, { status: 401 });
  }

  const target = `${backendUrl()}/api/${path.map(encodeURIComponent).join("/")}${req.nextUrl.search}`;
  const headers: Record<string, string> = { Authorization: `Bearer ${token}` };
  let body: string | undefined;
  if (req.method !== "GET" && req.method !== "HEAD") {
    body = await req.text();
    headers["Content-Type"] = req.headers.get("content-type") ?? "application/json";
  }

  let res: Response;
  try {
    res = await fetch(target, { method: req.method, headers, body, cache: "no-store" });
  } catch {
    return NextResponse.json({ success: false, message: "Backend haipatikani" }, { status: 502 });
  }

  // Inapitisha JSON na faili (mf. nyaraka za KYC) kama zilivyo
  const out = new Headers();
  for (const name of ["content-type", "content-disposition", "cache-control"]) {
    const value = res.headers.get(name);
    if (value) out.set(name, value);
  }
  return new NextResponse(res.body, { status: res.status, headers: out });
}

export { proxy as GET, proxy as POST, proxy as PUT, proxy as DELETE };
