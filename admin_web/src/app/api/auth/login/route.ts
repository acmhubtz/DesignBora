import { NextRequest, NextResponse } from "next/server";
import { ADMIN_COOKIE, backendUrl } from "@/lib/session";

export async function POST(req: NextRequest) {
  const body = await req.json().catch(() => ({}));

  let res: Response;
  try {
    res = await fetch(`${backendUrl()}/api/admin/auth/login`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ phone: body.phone, password: body.password, code: body.code || null }),
      cache: "no-store",
    });
  } catch {
    return NextResponse.json(
      { success: false, message: "Backend haipatikani. Hakikisha imewashwa." },
      { status: 502 },
    );
  }

  const json = await res.json().catch(() => ({}));
  if (!res.ok) {
    return NextResponse.json(
      { success: false, message: json.message ?? "Imeshindwa kuingia" },
      { status: res.status },
    );
  }

  const data = json.data ?? {};
  if (data.status === "OK" && data.token) {
    // Token inakaa kwenye cookie ya httpOnly - JavaScript ya kivinjari haiwezi kuisoma
    const response = NextResponse.json({ success: true, status: "OK", fullName: data.fullName });
    response.cookies.set(ADMIN_COOKIE, data.token, {
      httpOnly: true,
      secure: process.env.NODE_ENV === "production",
      sameSite: "strict",
      path: "/",
      maxAge: 8 * 60 * 60,
    });
    return response;
  }

  return NextResponse.json({
    success: true,
    status: data.status,
    fullName: data.fullName,
    otpauthUrl: data.otpauthUrl,
    secret: data.secret,
    message: json.message,
  });
}
