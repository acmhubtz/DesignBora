"use client";

import { useEffect, useMemo, useState } from "react";
import { api, formatDate, tsh, type DesignerActivity } from "@/lib/api";

const SORTS = {
  earnings: { label: "Mapato zaidi", fn: (a: DesignerActivity, b: DesignerActivity) => b.earnings - a.earnings },
  orders: { label: "Oda nyingi", fn: (a: DesignerActivity, b: DesignerActivity) => b.totalOrders - a.totalOrders },
  pending: {
    label: "Payout zinazosubiri",
    fn: (a: DesignerActivity, b: DesignerActivity) => b.pendingPayout - a.pendingPayout,
  },
  recent: {
    label: "Wapya kwanza",
    fn: (a: DesignerActivity, b: DesignerActivity) => (b.registeredAt ?? "").localeCompare(a.registeredAt ?? ""),
  },
} as const;
type SortKey = keyof typeof SORTS;

const STATUS_STYLE: Record<string, { label: string; style: string }> = {
  VERIFIED: { label: "Amethibitishwa", style: "bg-emerald-100 text-emerald-700" },
  PENDING: { label: "Inasubiri", style: "bg-orange-100 text-orange-700" },
  REJECTED: { label: "Amekataliwa", style: "bg-red-100 text-red-700" },
};

export default function DesignerActivityPage() {
  const [rows, setRows] = useState<DesignerActivity[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [query, setQuery] = useState("");
  const [sort, setSort] = useState<SortKey>("earnings");

  useEffect(() => {
    api<DesignerActivity[]>("admin/analytics/designers")
      .then(setRows)
      .catch((e) => setError(e instanceof Error ? e.message : "Imeshindwa kupakia"))
      .finally(() => setLoading(false));
  }, []);

  const visible = useMemo(() => {
    const q = query.trim().toLowerCase();
    return rows
      .filter((r) => !q || r.name.toLowerCase().includes(q) || r.phone.includes(q))
      .sort(SORTS[sort].fn);
  }, [rows, query, sort]);

  return (
    <div className="max-w-7xl">
      <h1 className="text-2xl font-extrabold">Shughuli za Wabunifu</h1>
      <p className="text-sm text-gray-500 mb-6">Oda, mapato na malipo ya kila mbunifu</p>

      <div className="flex flex-wrap gap-3 mb-4">
        <input
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder="Tafuta kwa jina au namba..."
          className="flex-1 min-w-60 rounded-xl border border-gray-200 bg-white px-4 py-2.5 text-sm outline-none focus:border-accent"
        />
        <select
          value={sort}
          onChange={(e) => setSort(e.target.value as SortKey)}
          className="rounded-xl border border-gray-200 bg-white px-4 py-2.5 text-sm"
        >
          {Object.entries(SORTS).map(([key, s]) => (
            <option key={key} value={key}>
              {s.label}
            </option>
          ))}
        </select>
      </div>

      {error && <div className="mb-4 rounded-xl bg-red-50 text-red-700 px-4 py-3 text-sm">{error}</div>}

      <div className="bg-white rounded-2xl shadow-sm overflow-x-auto">
        <table className="w-full text-sm min-w-[1000px]">
          <thead className="bg-gray-50 text-gray-500 text-left">
            <tr>
              <th className="px-4 py-3 font-semibold">Mbunifu</th>
              <th className="px-4 py-3 font-semibold">Hali</th>
              <th className="px-4 py-3 font-semibold text-right">Oda</th>
              <th className="px-4 py-3 font-semibold text-right">Zinaendelea</th>
              <th className="px-4 py-3 font-semibold text-right">Zimekamilika</th>
              <th className="px-4 py-3 font-semibold text-right">Migogoro</th>
              <th className="px-4 py-3 font-semibold text-right">Mauzo</th>
              <th className="px-4 py-3 font-semibold text-right">Mapato yake</th>
              <th className="px-4 py-3 font-semibold text-right">Amelipwa</th>
              <th className="px-4 py-3 font-semibold text-right">Inasubiri</th>
              <th className="px-4 py-3 font-semibold">Oda ya mwisho</th>
              <th className="px-4 py-3 font-semibold">Anapokea kwa</th>
            </tr>
          </thead>
          <tbody>
            {loading ? (
              <tr>
                <td colSpan={12} className="px-4 py-10 text-center text-gray-400">
                  Inapakia...
                </td>
              </tr>
            ) : visible.length === 0 ? (
              <tr>
                <td colSpan={12} className="px-4 py-10 text-center text-gray-400">
                  Hakuna mbunifu anayelingana
                </td>
              </tr>
            ) : (
              visible.map((r) => {
                const status = STATUS_STYLE[r.verificationStatus] ?? { label: r.verificationStatus, style: "bg-gray-100" };
                return (
                  <tr key={r.designerId} className="border-t hover:bg-gray-50">
                    <td className="px-4 py-3">
                      <div className="font-semibold">{r.name}</div>
                      <div className="text-xs text-gray-500">
                        +{r.phone.replace("+", "")} • Alijiunga {formatDate(r.registeredAt)}
                      </div>
                    </td>
                    <td className="px-4 py-3">
                      <span className={`px-2.5 py-1 rounded-full text-xs font-semibold ${status.style}`}>
                        {status.label}
                      </span>
                    </td>
                    <td className="px-4 py-3 text-right">{r.totalOrders}</td>
                    <td className="px-4 py-3 text-right">{r.activeOrders}</td>
                    <td className="px-4 py-3 text-right">{r.completedOrders}</td>
                    <td className={`px-4 py-3 text-right ${r.disputedOrders > 0 ? "text-red-600 font-bold" : ""}`}>
                      {r.disputedOrders}
                    </td>
                    <td className="px-4 py-3 text-right">{tsh(r.grossSales)}</td>
                    <td className="px-4 py-3 text-right font-semibold text-emerald-600">{tsh(r.earnings)}</td>
                    <td className="px-4 py-3 text-right">{tsh(r.paidOut)}</td>
                    <td className={`px-4 py-3 text-right ${r.pendingPayout > 0 ? "text-orange-600 font-semibold" : ""}`}>
                      {tsh(r.pendingPayout)}
                    </td>
                    <td className="px-4 py-3 text-gray-500">{formatDate(r.lastOrderAt)}</td>
                    <td className="px-4 py-3">
                      {r.payoutMethod === "BANK" ? "Benki" : r.payoutMethod === "MOBILE" ? "Simu" : (
                        <span className="text-orange-600 font-medium">Hajaweka</span>
                      )}
                    </td>
                  </tr>
                );
              })
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
