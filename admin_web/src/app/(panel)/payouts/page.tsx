"use client";

import { useCallback, useEffect, useState } from "react";
import {
  api,
  formatDate,
  PAYOUT_STATUS,
  tsh,
  type PayoutRow,
  type PayoutSummary,
  type RefundRow,
} from "@/lib/api";

const FILTERS = ["ALL", "PENDING", "PROCESSING", "FAILED", "PROCESSED"] as const;
type Filter = (typeof FILTERS)[number];

function Badge({ status }: { status: string }) {
  const s = PAYOUT_STATUS[status] ?? { label: status, style: "bg-gray-100 text-gray-700" };
  return <span className={`px-2.5 py-1 rounded-full text-xs font-semibold ${s.style}`}>{s.label}</span>;
}

export default function PayoutsPage() {
  const [tab, setTab] = useState<"payouts" | "refunds">("payouts");
  const [filter, setFilter] = useState<Filter>("ALL");
  const [summary, setSummary] = useState<PayoutSummary | null>(null);
  const [payouts, setPayouts] = useState<PayoutRow[]>([]);
  const [refunds, setRefunds] = useState<RefundRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [busyId, setBusyId] = useState<number | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const [s, list] = await Promise.all([
        api<PayoutSummary>("admin/payouts/summary"),
        tab === "payouts"
          ? api<PayoutRow[]>(`admin/payouts?status=${filter}`)
          : api<RefundRow[]>(`admin/payouts/refunds?status=${filter}`),
      ]);
      setSummary(s);
      if (tab === "payouts") setPayouts(list as PayoutRow[]);
      else setRefunds(list as RefundRow[]);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Imeshindwa kupakia");
    } finally {
      setLoading(false);
    }
  }, [tab, filter]);

  useEffect(() => {
    load();
  }, [load]);

  async function act(id: number, action: "retry" | "mark-paid") {
    const base = tab === "payouts" ? `admin/payouts/${id}` : `admin/payouts/refunds/${id}`;
    let body: string | undefined;
    if (action === "mark-paid") {
      const note = prompt(
        "Umelipa kwa mkono nje ya mfumo? Andika maelezo (mfano: M-Pesa ref QJK8XYZ, 05/10/2026):",
      );
      if (!note || note.trim().length < 3) return;
      body = JSON.stringify({ note: note.trim() });
    } else if (!confirm("Kurudisha kwenye foleni na kujaribu kutuma tena?")) {
      return;
    }
    setBusyId(id);
    try {
      await api(`${base}/${action}`, { method: "POST", body });
      await load();
    } catch (e) {
      alert(e instanceof Error ? e.message : "Imeshindwa");
    } finally {
      setBusyId(null);
    }
  }

  const counts = tab === "payouts" ? summary?.payoutCounts : summary?.refundCounts;

  function actions(id: number, status: string) {
    if (busyId === id) return <span className="text-xs text-gray-400">Inashughulikia...</span>;
    return (
      <div className="flex gap-2 justify-end">
        {status === "FAILED" && (
          <button onClick={() => act(id, "retry")} className="px-3 py-1.5 rounded-lg bg-brand text-white text-xs font-semibold">
            Jaribu tena
          </button>
        )}
        {(status === "FAILED" || status === "PENDING") && (
          <button onClick={() => act(id, "mark-paid")} className="px-3 py-1.5 rounded-lg border text-xs font-semibold hover:bg-gray-50">
            Imelipwa kwa mkono
          </button>
        )}
      </div>
    );
  }

  return (
    <div className="max-w-7xl">
      <h1 className="text-2xl font-extrabold">Malipo kwa Wabunifu na Wateja</h1>
      <p className="text-sm text-gray-500 mb-6">
        Foleni inatuma malipo moja kila sekunde ~70 kupitia ClickPesa
      </p>

      <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 mb-6">
        <div className="bg-white rounded-2xl p-5 shadow-sm">
          <div className="text-sm text-gray-500">Payouts ambazo bado hazijalipwa</div>
          <div className="text-2xl font-extrabold text-accent-dark">{tsh(summary?.payoutsWaiting)}</div>
        </div>
        <div className="bg-white rounded-2xl p-5 shadow-sm">
          <div className="text-sm text-gray-500">Refunds ambazo bado hazijalipwa</div>
          <div className="text-2xl font-extrabold text-red-600">{tsh(summary?.refundsWaiting)}</div>
        </div>
      </div>

      <div className="flex flex-wrap items-center justify-between gap-3 mb-4">
        <div className="flex gap-2">
          {(["payouts", "refunds"] as const).map((t) => (
            <button
              key={t}
              onClick={() => setTab(t)}
              className={`px-4 py-2 rounded-xl text-sm font-semibold ${
                tab === t ? "bg-brand text-white" : "bg-white border hover:bg-gray-50"
              }`}
            >
              {t === "payouts" ? "Payouts (wabunifu)" : "Refunds (wateja)"}
            </button>
          ))}
        </div>
        <div className="flex flex-wrap gap-2">
          {FILTERS.map((f) => (
            <button
              key={f}
              onClick={() => setFilter(f)}
              className={`px-3 py-1.5 rounded-lg text-xs font-semibold ${
                filter === f ? "bg-accent text-white" : "bg-white border hover:bg-gray-50"
              }`}
            >
              {f === "ALL" ? "Zote" : PAYOUT_STATUS[f]?.label}
              {f !== "ALL" && counts?.[f] ? ` (${counts[f]})` : ""}
            </button>
          ))}
        </div>
      </div>

      {error && <div className="mb-4 rounded-xl bg-red-50 text-red-700 px-4 py-3 text-sm">{error}</div>}

      <div className="bg-white rounded-2xl shadow-sm overflow-x-auto">
        {tab === "payouts" ? (
          <table className="w-full text-sm min-w-[900px]">
            <thead className="bg-gray-50 text-gray-500 text-left">
              <tr>
                <th className="px-4 py-3 font-semibold">#</th>
                <th className="px-4 py-3 font-semibold">Mbunifu</th>
                <th className="px-4 py-3 font-semibold">Kwenda</th>
                <th className="px-4 py-3 font-semibold text-right">Kiasi</th>
                <th className="px-4 py-3 font-semibold">Hali</th>
                <th className="px-4 py-3 font-semibold">Tarehe</th>
                <th className="px-4 py-3" />
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <tr><td colSpan={7} className="px-4 py-10 text-center text-gray-400">Inapakia...</td></tr>
              ) : payouts.length === 0 ? (
                <tr><td colSpan={7} className="px-4 py-10 text-center text-gray-400">Hakuna payouts hapa</td></tr>
              ) : (
                payouts.map((p) => (
                  <tr key={p.id} className="border-t align-top">
                    <td className="px-4 py-3 text-gray-500">
                      #{p.id}
                      <div className="text-xs">Oda #{p.orderId}</div>
                    </td>
                    <td className="px-4 py-3">
                      <div className="font-semibold">{p.designerName}</div>
                      <div className="text-xs text-gray-500">+{p.designerPhone.replace("+", "")}</div>
                    </td>
                    <td className="px-4 py-3">
                      {p.destination ? (
                        <>
                          <div>{p.channel === "BANK" ? "Benki" : "Simu"}</div>
                          <div className="text-xs text-gray-500">{p.destination}</div>
                        </>
                      ) : (
                        <span className="text-orange-600 font-medium">Hajaweka njia ya malipo</span>
                      )}
                      {p.failureReason && <div className="text-xs text-red-600 mt-1">{p.failureReason}</div>}
                    </td>
                    <td className="px-4 py-3 text-right font-bold">{tsh(p.amount)}</td>
                    <td className="px-4 py-3"><Badge status={p.status} /></td>
                    <td className="px-4 py-3 text-xs text-gray-500">
                      {formatDate(p.createdAt)}
                      {p.processedAt && <div>Ililipwa: {formatDate(p.processedAt)}</div>}
                    </td>
                    <td className="px-4 py-3">{actions(p.id, p.status)}</td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        ) : (
          <table className="w-full text-sm min-w-[900px]">
            <thead className="bg-gray-50 text-gray-500 text-left">
              <tr>
                <th className="px-4 py-3 font-semibold">#</th>
                <th className="px-4 py-3 font-semibold">Mteja</th>
                <th className="px-4 py-3 font-semibold">Kwenda</th>
                <th className="px-4 py-3 font-semibold text-right">Kiasi</th>
                <th className="px-4 py-3 font-semibold">Hali</th>
                <th className="px-4 py-3 font-semibold">Tarehe</th>
                <th className="px-4 py-3" />
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <tr><td colSpan={7} className="px-4 py-10 text-center text-gray-400">Inapakia...</td></tr>
              ) : refunds.length === 0 ? (
                <tr><td colSpan={7} className="px-4 py-10 text-center text-gray-400">Hakuna refunds hapa</td></tr>
              ) : (
                refunds.map((r) => (
                  <tr key={r.id} className="border-t align-top">
                    <td className="px-4 py-3 text-gray-500">
                      #{r.id}
                      <div className="text-xs">Oda #{r.orderId}</div>
                    </td>
                    <td className="px-4 py-3 font-semibold">{r.customerName}</td>
                    <td className="px-4 py-3">
                      {r.phone ? `+${r.phone}` : <span className="text-orange-600 font-medium">Hakuna namba — lipa kwa mkono</span>}
                      {r.failureReason && <div className="text-xs text-red-600 mt-1">{r.failureReason}</div>}
                    </td>
                    <td className="px-4 py-3 text-right font-bold">{tsh(r.amount)}</td>
                    <td className="px-4 py-3"><Badge status={r.status} /></td>
                    <td className="px-4 py-3 text-xs text-gray-500">
                      {formatDate(r.createdAt)}
                      {r.processedAt && <div>Ililipwa: {formatDate(r.processedAt)}</div>}
                    </td>
                    <td className="px-4 py-3">{actions(r.id, r.status)}</td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        )}
      </div>
    </div>
  );
}
