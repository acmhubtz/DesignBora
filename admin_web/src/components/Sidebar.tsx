"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { useState } from "react";

const links = [
  { href: "/dashboard", label: "Dashibodi" },
  { href: "/designers", label: "Uhakiki wa Wabunifu" },
  { href: "/designer-activity", label: "Shughuli za Wabunifu" },
  { href: "/reports", label: "Ripoti" },
  { href: "/audit", label: "Kumbukumbu za Admin" },
];

export default function Sidebar() {
  const pathname = usePathname();
  const router = useRouter();
  const [busy, setBusy] = useState(false);

  async function logout() {
    setBusy(true);
    await fetch("/api/auth/logout", { method: "POST" });
    router.replace("/login");
    router.refresh();
  }

  return (
    <aside className="bg-brand text-white md:w-64 md:min-h-screen flex md:flex-col">
      <div className="hidden md:flex items-center gap-3 p-5 border-b border-white/10">
        <div className="w-9 h-9 rounded-lg bg-accent flex items-center justify-center font-extrabold">B</div>
        <div>
          <div className="font-bold">DesignBora</div>
          <div className="text-xs text-white/60">Admin Panel</div>
        </div>
      </div>
      <nav className="flex md:flex-col gap-1 p-3 flex-1 overflow-x-auto">
        {links.map((link) => {
          const active = pathname.startsWith(link.href);
          return (
            <Link
              key={link.href}
              href={link.href}
              className={`whitespace-nowrap px-3 py-2 rounded-lg text-sm font-medium ${
                active ? "bg-white/15 text-white" : "text-white/75 hover:bg-white/10"
              }`}
            >
              {link.label}
            </Link>
          );
        })}
      </nav>
      <div className="p-3">
        <button
          onClick={logout}
          disabled={busy}
          className="w-full whitespace-nowrap px-3 py-2 rounded-lg text-sm bg-white/10 hover:bg-white/20"
        >
          {busy ? "Inatoka..." : "Toka"}
        </button>
      </div>
    </aside>
  );
}
