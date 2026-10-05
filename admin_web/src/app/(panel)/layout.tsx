import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import Sidebar from "@/components/Sidebar";
import { ADMIN_COOKIE } from "@/lib/session";

/** Kila ukurasa ndani ya (panel) unahitaji admin aliyeingia */
export default async function PanelLayout({ children }: { children: React.ReactNode }) {
  const token = (await cookies()).get(ADMIN_COOKIE)?.value;
  if (!token) redirect("/login");

  return (
    <div className="min-h-screen flex flex-col md:flex-row">
      <Sidebar />
      <main className="flex-1 p-4 md:p-8 overflow-x-auto">{children}</main>
    </div>
  );
}
