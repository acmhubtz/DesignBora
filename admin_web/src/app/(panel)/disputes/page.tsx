"use client";

import { useCallback, useEffect, useState } from "react";
import {
  api,
  formatDate,
  RESOLUTION_LABELS,
  tsh,
  type DisputeDetail,
  type DisputeSummary,
} from "@/lib/api";

const OPTIONS = [
  {
    key: "PAY_DESIGNER",
    title: "Mlipe mbunifu",
    text: "Kazi inakidhi makubaliano. Oda inakamilika na payout inatumwa.",
    style: "border-emerald-500 bg-emerald-50",
  },
  {
    key: "REFUND_CUSTOMER",
    title: "Mrudishie mteja pesa",
    text: "Kazi haikidhi. Oda inaghairiwa na mteja anarudishiwa kiasi chote.",
    style: "border-red-500 bg-red-50",
  },
  {
    key: "REVISION",
    title: "Rudisha kwa marekebisho",
    text: "Mbunifu afanye marekebisho na atume draft mpya.",
    style: "border-blue-500 bg-blue-50",
  },
] as const;

export default function DisputesPage() {
  const [status, setStatus] = useState<"OPEN" | "RESOLVED">("OPEN");
  const [rows, setRows] = useState<DisputeSummary[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [detail, setDetail] = useState<DisputeDetail | null>(null);
  const [resolution, setResolution] = useState<string>("");
  const [note, setNote] = useState("");
  const [working, setWorking] = useState(false);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      setRows(await api<DisputeSummary[]>(`admin/disputes?status=${status}`));
    } catch (e) {
      setError(e instanceof Error ? e.message : "Imeshindwa kupakia");
    } finally {
      setLoading(false);
    }
  }, [status]);

  useEffect(() => {
    load();
  }, [load]);

  async function open(id: number) {
    setResolution("");
    setNote("");
    try {
      setDetail(await api<DisputeDetail>(`admin/disputes/${id}`));
    } catch (e) {
      alert(e instanceof Error ? e.message : "Imeshindwa kufungua");
    }
  }

  async function resolve() {
    if (!detail || !resolution) return;
    if (note.trim().length < 5) {
      alert("Andika maelezo ya uamuzi - pande zote mbili zitayaona kwenye chat");
      return;
    }
    if (!confirm(`Thibitisha uamuzi: ${RESOLUTION_LABELS[resolution]}? Hatua hii haiwezi kurudishwa.`)) return;
    setWorking(true);
    try {
      await api(`admin/disputes/${detail.summary.id}/resolve`, {
        method: "POST",
        body: JSON.stringify({ resolution, note: note.trim() }),
      });
      setDetail(null);
      await load();
    } catch (e) {
      alert(e instanceof Error ? e.message : "Imeshindwa");
    } finally {
      setWorking(false);
    }
  }

  const s = detail?.summary;

  return (
    <div className="max-w-6xl">
      <div className="flex flex-wrap items-center justify-between gap-3 mb-6">
        <div>
          <h1 className="text-2xl font-extrabold">Migogoro</h1>
          <p className="text-sm text-gray-500">Kagua mazungumzo na kazi, kisha toa uamuzi wa haki</p>
        </div>
        <div className="flex gap-2">
          {(["OPEN", "RESOLVED"] as const).map((st) => (
            <button
              key={st}
              onClick={() => setStatus(st)}
              className={`px-4 py-2 rounded-xl text-sm font-semibold ${
                status === st ? "bg-brand text-white" : "bg-white border hover:bg-gray-50"
              }`}
            >
              {st === "OPEN" ? "Inasubiri uamuzi" : "Imetatuliwa"}
            </button>
          ))}
        </div>
      </div>

      {error && <div className="mb-4 rounded-xl bg-red-50 text-red-700 px-4 py-3 text-sm">{error}</div>}

      <div className="space-y-3">
        {loading ? (
          <div className="text-gray-400">Inapakia...</div>
        ) : rows.length === 0 ? (
          <div className="bg-white rounded-2xl p-10 text-center text-gray-400">
            {status === "OPEN" ? "Hakuna mgogoro unaosubiri uamuzi 🎉" : "Bado hakuna migogoro iliyotatuliwa"}
          </div>
        ) : (
          rows.map((r) => (
            <button
              key={r.id}
              onClick={() => open(r.id)}
              className="w-full text-left bg-white rounded-2xl p-5 shadow-sm hover:shadow-md transition"
            >
              <div className="flex flex-wrap items-start justify-between gap-2">
                <div>
                  <div className="font-bold">
                    Oda #{r.orderId} • {r.serviceTitle}
                  </div>
                  <div className="text-sm text-gray-500">
                    Mteja: {r.customer.name} • Mbunifu: {r.designer.name}
                  </div>
                </div>
                <div className="text-right">
                  <div className="font-extrabold text-brand">{tsh(r.grossAmount)}</div>
                  <div className="text-xs text-gray-400">{formatDate(r.createdAt)}</div>
                </div>
              </div>
              <p className="mt-3 text-sm text-gray-700 line-clamp-2">“{r.reason}”</p>
              {r.resolution && (
                <span className="inline-block mt-3 px-2.5 py-1 rounded-full text-xs font-semibold bg-indigo-100 text-indigo-700">
                  {RESOLUTION_LABELS[r.resolution] ?? r.resolution}
                </span>
              )}
            </button>
          ))
        )}
      </div>

      {detail && s && (
        <div className="fixed inset-0 bg-black/40 flex justify-end z-50" onClick={() => setDetail(null)}>
          <div className="w-full max-w-3xl bg-page h-full overflow-y-auto" onClick={(e) => e.stopPropagation()}>
            <div className="sticky top-0 bg-white border-b px-6 py-4 flex items-center justify-between">
              <div>
                <div className="font-extrabold text-lg">Mgogoro wa Oda #{s.orderId}</div>
                <div className="text-sm text-gray-500">{s.serviceTitle}</div>
              </div>
              <button onClick={() => setDetail(null)} className="text-2xl text-gray-400 hover:text-gray-800">
                ×
              </button>
            </div>

            <div className="p-6 space-y-5">
              <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
                <div className="bg-white rounded-xl p-4">
                  <div className="text-xs text-gray-500">Mteja</div>
                  <div className="font-semibold">{s.customer.name}</div>
                  <div className="text-xs text-gray-500">+{s.customer.phone.replace("+", "")}</div>
                </div>
                <div className="bg-white rounded-xl p-4">
                  <div className="text-xs text-gray-500">Mbunifu</div>
                  <div className="font-semibold">{s.designer.name}</div>
                  <div className="text-xs text-gray-500">+{s.designer.phone.replace("+", "")}</div>
                </div>
                <div className="bg-white rounded-xl p-4">
                  <div className="text-xs text-gray-500">Kiasi (Escrow)</div>
                  <div className="font-extrabold text-brand">{tsh(s.grossAmount)}</div>
                  <div className="text-xs text-gray-500">
                    Mbunifu: {tsh(s.netAmount)} • Ada: {tsh(s.platformFee)}
                  </div>
                </div>
              </div>

              <div className="bg-red-50 border border-red-200 rounded-xl p-4">
                <div className="text-xs font-bold text-red-700 mb-1">SABABU YA MTEJA</div>
                <p className="text-sm whitespace-pre-wrap">{s.reason}</p>
              </div>

              <section className="bg-white rounded-xl p-4">
                <h3 className="font-bold mb-3">Drafts ({detail.drafts.length})</h3>
                {detail.drafts.length === 0 ? (
                  <p className="text-sm text-gray-400">Mbunifu hajatuma draft yoyote.</p>
                ) : (
                  <div className="space-y-2">
                    {detail.drafts.map((d) => (
                      <div key={d.id} className="flex flex-wrap items-center justify-between gap-2 border rounded-lg px-3 py-2">
                        <div className="text-sm">
                          <span className="font-semibold">v{d.versionNo}</span> • {d.extension.toUpperCase()} •{" "}
                          {formatDate(d.submittedAt)}
                        </div>
                        <div className="flex gap-2">
                          {d.previewUrl && (
                            <a
                              href={`/api/backend${d.previewUrl}`}
                              target="_blank"
                              className="px-3 py-1.5 rounded-lg border text-xs font-semibold hover:bg-gray-50"
                            >
                              Preview
                            </a>
                          )}
                          <a
                            href={`/api/backend/admin/disputes/${s.id}/drafts/${d.id}/original`}
                            target="_blank"
                            className="px-3 py-1.5 rounded-lg bg-brand text-white text-xs font-semibold"
                          >
                            Faili la asili
                          </a>
                        </div>
                      </div>
                    ))}
                  </div>
                )}
              </section>

              <section className="bg-white rounded-xl p-4">
                <h3 className="font-bold mb-3">Mazungumzo ({detail.messages.length})</h3>
                <div className="space-y-2 max-h-96 overflow-y-auto pr-1">
                  {detail.messages.length === 0 ? (
                    <p className="text-sm text-gray-400">Hakuna ujumbe.</p>
                  ) : (
                    detail.messages.map((m) => {
                      const isCustomer = m.senderRole === "CUSTOMER";
                      const isAdmin = m.senderRole === "ADMIN";
                      return (
                        <div
                          key={m.id}
                          className={`rounded-xl px-3 py-2 text-sm max-w-[85%] ${
                            isAdmin
                              ? "mx-auto bg-indigo-50 border border-indigo-200"
                              : isCustomer
                                ? "bg-gray-100"
                                : "ml-auto bg-brand/10"
                          }`}
                        >
                          <div className="text-xs font-semibold text-gray-500">
                            {m.senderName} • {isAdmin ? "Admin" : isCustomer ? "Mteja" : "Mbunifu"} •{" "}
                            {formatDate(m.sentAt)}
                          </div>
                          <div className="whitespace-pre-wrap">{m.message}</div>
                        </div>
                      );
                    })
                  )}
                </div>
              </section>

              {detail.refund && (
                <div className="bg-white rounded-xl p-4 text-sm">
                  <span className="font-bold">Refund:</span> {tsh(detail.refund.amount)} kwenda{" "}
                  {detail.refund.phone ? `+${detail.refund.phone}` : "(hakuna namba)"} — {detail.refund.status}
                  {detail.refund.failureReason && (
                    <div className="text-xs text-red-600 mt-1">{detail.refund.failureReason}</div>
                  )}
                </div>
              )}

              {s.status === "OPEN" ? (
                <section className="bg-white rounded-xl p-4 space-y-3">
                  <h3 className="font-bold">Toa uamuzi</h3>
                  <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
                    {OPTIONS.map((o) => (
                      <button
                        key={o.key}
                        onClick={() => setResolution(o.key)}
                        className={`text-left rounded-xl border-2 p-3 ${
                          resolution === o.key ? o.style : "border-gray-200 hover:border-gray-300"
                        }`}
                      >
                        <div className="font-bold text-sm">{o.title}</div>
                        <div className="text-xs text-gray-600 mt-1">{o.text}</div>
                      </button>
                    ))}
                  </div>
                  <textarea
                    value={note}
                    onChange={(e) => setNote(e.target.value)}
                    rows={3}
                    placeholder="Maelezo ya uamuzi (yataonekana kwenye chat kwa mteja na mbunifu)"
                    className="w-full rounded-xl border border-gray-200 px-4 py-3 text-sm outline-none focus:border-accent"
                  />
                  <button
                    disabled={!resolution || working}
                    onClick={resolve}
                    className="w-full rounded-xl bg-accent hover:bg-accent-dark text-white font-bold py-3 disabled:opacity-50"
                  >
                    {working ? "Inahifadhi..." : "Thibitisha Uamuzi"}
                  </button>
                </section>
              ) : (
                <div className="bg-indigo-50 border border-indigo-200 rounded-xl p-4 text-sm">
                  <div className="font-bold">
                    Uamuzi: {RESOLUTION_LABELS[s.resolution ?? ""] ?? s.resolution} • {formatDate(s.resolvedAt)}
                  </div>
                  <p className="mt-1 whitespace-pre-wrap">{s.adminNote}</p>
                </div>
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
