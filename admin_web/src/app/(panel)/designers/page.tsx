"use client";

import { useCallback, useEffect, useState } from "react";
import {
  accountTypeLabel,
  api,
  documentTypeLabel,
  formatDate,
  type DesignerItem,
  type Stats,
} from "@/lib/api";

const STATUSES = [
  { key: "PENDING", label: "Wanasubiri", color: "text-accent-dark" },
  { key: "VERIFIED", label: "Wamethibitishwa", color: "text-emerald-600" },
  { key: "REJECTED", label: "Wamekataliwa", color: "text-red-600" },
] as const;
type StatusKey = (typeof STATUSES)[number]["key"];

function StatusBadge({ status }: { status: string }) {
  const style: Record<string, string> = {
    PENDING: "bg-orange-100 text-orange-700",
    VERIFIED: "bg-emerald-100 text-emerald-700",
    APPROVED: "bg-emerald-100 text-emerald-700",
    REJECTED: "bg-red-100 text-red-700",
  };
  const label: Record<string, string> = {
    PENDING: "Inasubiri",
    VERIFIED: "Amethibitishwa",
    APPROVED: "Imekubaliwa",
    REJECTED: "Imekataliwa",
  };
  return (
    <span className={`px-2.5 py-1 rounded-full text-xs font-semibold ${style[status] ?? "bg-gray-100 text-gray-600"}`}>
      {label[status] ?? status}
    </span>
  );
}

export default function DesignersPage() {
  const [status, setStatus] = useState<StatusKey>("PENDING");
  const [stats, setStats] = useState<Stats | null>(null);
  const [designers, setDesigners] = useState<DesignerItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [selected, setSelected] = useState<DesignerItem | null>(null);
  const [working, setWorking] = useState(false);
  const [rejectReason, setRejectReason] = useState("");
  const [showReject, setShowReject] = useState(false);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const [s, list] = await Promise.all([
        api<Stats>("admin/verification/stats"),
        api<DesignerItem[]>(`admin/verification/designers?status=${status}`),
      ]);
      setStats(s);
      setDesigners(list);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Imeshindwa kupakia");
    } finally {
      setLoading(false);
    }
  }, [status]);

  useEffect(() => {
    load();
  }, [load]);

  function closeDetail() {
    setSelected(null);
    setShowReject(false);
    setRejectReason("");
  }

  async function openDocument(documentId: number) {
    // Fungua dirisha mara moja (kuepuka popup blocker), kisha weka kiungo cha muda
    const win = window.open("", "_blank");
    try {
      const data = await api<{ url: string }>(`verification-documents/${documentId}/link`, { method: "POST" });
      const proxied = data.url.replace(/^\/api\//, "/api/backend/");
      if (win) win.location.href = proxied;
      else window.location.href = proxied;
    } catch (e) {
      win?.close();
      alert(e instanceof Error ? e.message : "Imeshindwa kufungua nyaraka");
    }
  }

  async function approve(designer: DesignerItem) {
    const warning = designer.documents.length === 0 ? "\n\nTAHADHARI: Hajapakia nyaraka yoyote!" : "";
    if (!confirm(`Kumthibitisha ${designer.fullName}?${warning}`)) return;
    setWorking(true);
    try {
      await api(`admin/verification/designers/${designer.designerId}/approve`, { method: "POST" });
      closeDetail();
      await load();
    } catch (e) {
      alert(e instanceof Error ? e.message : "Imeshindwa");
    } finally {
      setWorking(false);
    }
  }

  async function reject(designer: DesignerItem) {
    if (!rejectReason.trim()) {
      alert("Andika sababu ili mbunifu ajue cha kurekebisha");
      return;
    }
    setWorking(true);
    try {
      await api(`admin/verification/designers/${designer.designerId}/reject`, {
        method: "POST",
        body: JSON.stringify({ reason: rejectReason.trim() }),
      });
      closeDetail();
      await load();
    } catch (e) {
      alert(e instanceof Error ? e.message : "Imeshindwa");
    } finally {
      setWorking(false);
    }
  }

  const counts: Record<StatusKey, number | undefined> = {
    PENDING: stats?.pending,
    VERIFIED: stats?.verified,
    REJECTED: stats?.rejected,
  };

  return (
    <div className="max-w-6xl">
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-2xl font-extrabold">Uhakiki wa Wabunifu</h1>
          <p className="text-sm text-gray-500">Kagua nyaraka, kisha thibitisha au kataa</p>
        </div>
        <button onClick={load} className="px-4 py-2 rounded-xl bg-white border text-sm font-semibold hover:bg-gray-50">
          Sasisha
        </button>
      </div>

      <div className="grid grid-cols-3 gap-3 mb-6">
        {STATUSES.map((s) => (
          <button
            key={s.key}
            onClick={() => setStatus(s.key)}
            className={`rounded-2xl p-4 text-left bg-white border-2 transition ${
              status === s.key ? "border-accent shadow-sm" : "border-transparent hover:border-gray-200"
            }`}
          >
            <div className={`text-3xl font-extrabold ${s.color}`}>{counts[s.key] ?? "-"}</div>
            <div className="text-sm font-semibold text-gray-600">{s.label}</div>
          </button>
        ))}
      </div>

      {error && <div className="mb-4 rounded-xl bg-red-50 text-red-700 px-4 py-3 text-sm">{error}</div>}

      <div className="bg-white rounded-2xl shadow-sm overflow-hidden">
        <table className="w-full text-sm">
          <thead className="bg-gray-50 text-gray-500 text-left">
            <tr>
              <th className="px-4 py-3 font-semibold">Mbunifu</th>
              <th className="px-4 py-3 font-semibold hidden md:table-cell">Aina</th>
              <th className="px-4 py-3 font-semibold hidden md:table-cell">Nyaraka</th>
              <th className="px-4 py-3 font-semibold hidden lg:table-cell">Alisajiliwa</th>
              <th className="px-4 py-3 font-semibold">Hali</th>
              <th className="px-4 py-3" />
            </tr>
          </thead>
          <tbody>
            {loading ? (
              <tr>
                <td colSpan={6} className="px-4 py-10 text-center text-gray-400">
                  Inapakia...
                </td>
              </tr>
            ) : designers.length === 0 ? (
              <tr>
                <td colSpan={6} className="px-4 py-10 text-center text-gray-400">
                  Hakuna wabunifu hapa
                </td>
              </tr>
            ) : (
              designers.map((d) => (
                <tr key={d.designerId} className="border-t hover:bg-gray-50">
                  <td className="px-4 py-3">
                    <div className="flex items-center gap-3">
                      <div className="w-9 h-9 rounded-full bg-brand text-white flex items-center justify-center font-bold">
                        {d.fullName.trim().charAt(0).toUpperCase() || "?"}
                      </div>
                      <div>
                        <div className="font-semibold">{d.fullName}</div>
                        <div className="text-xs text-gray-500">+{d.phone.replace("+", "")}</div>
                      </div>
                    </div>
                  </td>
                  <td className="px-4 py-3 hidden md:table-cell">{accountTypeLabel(d.accountType)}</td>
                  <td className="px-4 py-3 hidden md:table-cell">
                    {d.documents.length === 0 ? (
                      <span className="text-orange-600 font-medium">Hajapakia</span>
                    ) : (
                      d.documents.length
                    )}
                  </td>
                  <td className="px-4 py-3 hidden lg:table-cell text-gray-500">{formatDate(d.createdAt)}</td>
                  <td className="px-4 py-3">
                    <StatusBadge status={d.verificationStatus} />
                  </td>
                  <td className="px-4 py-3 text-right">
                    <button
                      onClick={() => setSelected(d)}
                      className="px-3 py-1.5 rounded-lg bg-brand text-white text-xs font-semibold hover:bg-brand-light"
                    >
                      Kagua
                    </button>
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>

      {selected && (
        <div className="fixed inset-0 bg-black/40 flex justify-end z-50" onClick={closeDetail}>
          <div className="w-full max-w-lg bg-white h-full overflow-y-auto p-6" onClick={(e) => e.stopPropagation()}>
            <div className="flex items-start justify-between mb-5">
              <div>
                <h2 className="text-xl font-extrabold">{selected.fullName}</h2>
                <div className="mt-1">
                  <StatusBadge status={selected.verificationStatus} />
                </div>
              </div>
              <button onClick={closeDetail} className="text-gray-400 hover:text-gray-800 text-2xl leading-none">
                ×
              </button>
            </div>

            <dl className="space-y-2 text-sm mb-6">
              {[
                ["Simu", `+${selected.phone.replace("+", "")}`],
                ["Barua pepe", selected.email ?? "-"],
                ["Aina ya akaunti", accountTypeLabel(selected.accountType)],
                ...(selected.accountType === "COMPANY"
                  ? [
                      ["Kampuni", selected.companyName ?? "-"],
                      ["Namba ya BRELA", selected.companyRegNumber ?? "-"],
                    ]
                  : []),
                ["Alisajiliwa", formatDate(selected.createdAt)],
                ...(selected.verificationNote ? [["Sababu ya awali", selected.verificationNote]] : []),
              ].map(([label, value]) => (
                <div key={label} className="flex gap-3">
                  <dt className="w-36 text-gray-500 shrink-0">{label}</dt>
                  <dd className="font-medium">{value}</dd>
                </div>
              ))}
            </dl>

            <h3 className="text-xs font-bold tracking-wider text-gray-500 mb-3">NYARAKA ZA UTHIBITISHO</h3>
            {selected.documents.length === 0 ? (
              <div className="rounded-xl bg-orange-50 text-orange-700 text-sm px-4 py-3 mb-6">
                Mbunifu huyu bado hajapakia nyaraka yoyote.
              </div>
            ) : (
              <div className="space-y-2 mb-6">
                {selected.documents.map((doc) => (
                  <div key={doc.id} className="flex items-center justify-between rounded-xl border px-4 py-3">
                    <div>
                      <div className="font-semibold text-sm">{documentTypeLabel(doc.documentType)}</div>
                      <div className="text-xs text-gray-500">
                        {doc.extension.toUpperCase()} • {formatDate(doc.uploadedAt)}
                      </div>
                    </div>
                    <div className="flex items-center gap-2">
                      <StatusBadge status={doc.status} />
                      <button
                        onClick={() => openDocument(doc.id)}
                        className="px-3 py-1.5 rounded-lg border text-xs font-semibold hover:bg-gray-50"
                      >
                        Fungua
                      </button>
                    </div>
                  </div>
                ))}
              </div>
            )}

            {showReject && (
              <div className="mb-4">
                <label className="block text-sm font-semibold mb-1.5">Sababu ya kukataa</label>
                <textarea
                  value={rejectReason}
                  onChange={(e) => setRejectReason(e.target.value)}
                  rows={3}
                  placeholder="Mfano: Picha ya kitambulisho haisomeki. Pakia picha iliyo wazi."
                  className="w-full rounded-xl border border-gray-200 px-4 py-3 text-sm outline-none focus:border-accent"
                />
              </div>
            )}

            <div className="flex gap-3">
              {selected.verificationStatus !== "REJECTED" &&
                (showReject ? (
                  <button
                    disabled={working}
                    onClick={() => reject(selected)}
                    className="flex-1 rounded-xl bg-red-600 hover:bg-red-700 text-white font-bold py-3 disabled:opacity-60"
                  >
                    Thibitisha Kukataa
                  </button>
                ) : (
                  <button
                    onClick={() => setShowReject(true)}
                    className="flex-1 rounded-xl border-2 border-red-600 text-red-600 font-bold py-3 hover:bg-red-50"
                  >
                    Kataa
                  </button>
                ))}
              {selected.verificationStatus !== "VERIFIED" && !showReject && (
                <button
                  disabled={working}
                  onClick={() => approve(selected)}
                  className="flex-1 rounded-xl bg-emerald-600 hover:bg-emerald-700 text-white font-bold py-3 disabled:opacity-60"
                >
                  {working ? "Inashughulikia..." : "Thibitisha"}
                </button>
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
