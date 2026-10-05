"use client";

import { useCallback, useEffect, useState } from "react";
import {
  Area,
  AreaChart,
  Bar,
  BarChart,
  CartesianGrid,
  Cell,
  Legend,
  Pie,
  PieChart,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";
import { api, ORDER_STATUS_LABELS, PROVIDER_LABELS, shortTsh, tsh, type Overview } from "@/lib/api";

const RANGES = [7, 30, 90, 365];
const PIE_COLORS = ["#0B3B3E", "#F07F2B", "#059669", "#2563EB", "#8B5CF6", "#DC2626", "#D97706"];

function MoneyCard({ label, value, hint, accent }: { label: string; value: number; hint?: string; accent: string }) {
  return (
    <div className="bg-white rounded-2xl p-5 shadow-sm">
      <div className="text-sm text-gray-500 font-medium">{label}</div>
      <div className={`mt-1 text-2xl font-extrabold ${accent}`}>{tsh(value)}</div>
      {hint && <div className="mt-1 text-xs text-gray-400">{hint}</div>}
    </div>
  );
}

function CountCard({ label, value, sub }: { label: string; value: number; sub?: string }) {
  return (
    <div className="bg-white rounded-2xl p-5 shadow-sm">
      <div className="text-sm text-gray-500 font-medium">{label}</div>
      <div className="mt-1 text-3xl font-extrabold text-brand">{value}</div>
      {sub && <div className="mt-1 text-xs text-gray-500">{sub}</div>}
    </div>
  );
}

function ChartCard({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div className="bg-white rounded-2xl p-5 shadow-sm">
      <h3 className="font-bold mb-4">{title}</h3>
      <div className="h-72">{children}</div>
    </div>
  );
}

export default function DashboardPage() {
  const [days, setDays] = useState(30);
  const [data, setData] = useState<Overview | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      setData(await api<Overview>(`admin/analytics/overview?days=${days}`));
    } catch (e) {
      setError(e instanceof Error ? e.message : "Imeshindwa kupakia takwimu");
    } finally {
      setLoading(false);
    }
  }, [days]);

  useEffect(() => {
    load();
  }, [load]);

  const daily = (data?.daily ?? []).map((d) => ({ ...d, label: d.date.slice(5) }));
  const statusData = (data?.ordersByStatus ?? []).map((s) => ({ ...s, label: ORDER_STATUS_LABELS[s.name] ?? s.name }));
  const providerData = (data?.paymentsByProvider ?? []).map((p) => ({ ...p, label: PROVIDER_LABELS[p.name] ?? p.name }));

  return (
    <div className="max-w-7xl space-y-6">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 className="text-2xl font-extrabold">Dashibodi</h1>
          <p className="text-sm text-gray-500">Muhtasari wa pesa, oda na watumiaji wa DesignBora</p>
        </div>
        <div className="flex gap-2">
          {RANGES.map((r) => (
            <button
              key={r}
              onClick={() => setDays(r)}
              className={`px-3 py-1.5 rounded-lg text-sm font-semibold ${
                days === r ? "bg-brand text-white" : "bg-white border hover:bg-gray-50"
              }`}
            >
              Siku {r}
            </button>
          ))}
        </div>
      </div>

      {error && <div className="rounded-xl bg-red-50 text-red-700 px-4 py-3 text-sm">{error}</div>}
      {loading && !data && <div className="text-gray-400">Inapakia takwimu...</div>}

      {data && (
        <>
          <section>
            <h2 className="text-xs font-bold tracking-wider text-gray-500 mb-3">PESA (JUMLA YA MUDA WOTE)</h2>
            <div className="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-4 gap-4">
              <MoneyCard label="Jumla iliyokusanywa" value={data.money.totalCollected} accent="text-brand"
                hint="Malipo yote ya wateja" />
              <MoneyCard label="Kwenye Escrow sasa" value={data.money.escrowHeld} accent="text-accent-dark"
                hint="Oda zilizolipwa, bado hazijakamilika" />
              <MoneyCard label="Ada ya platform (imepatikana)" value={data.money.platformFeesEarned}
                accent="text-emerald-600" hint={`Inasubiri: ${tsh(data.money.platformFeesPending)}`} />
              <MoneyCard label="Imelipwa kwa wabunifu" value={data.money.paidToDesigners} accent="text-blue-600"
                hint={`Zinasubiri: ${tsh(data.money.payoutsPending)}${
                  data.money.payoutsFailed > 0 ? ` • Zimeshindwa: ${tsh(data.money.payoutsFailed)}` : ""
                }`} />
            </div>
          </section>

          <section>
            <h2 className="text-xs font-bold tracking-wider text-gray-500 mb-3">IDADI</h2>
            <div className="grid grid-cols-2 xl:grid-cols-4 gap-4">
              <CountCard label="Wateja" value={data.counts.customers}
                sub={`Watumiaji wapya (siku ${data.days}): ${data.counts.newUsersInRange}`} />
              <CountCard label="Wabunifu" value={data.counts.designers}
                sub={`${data.counts.verifiedDesigners} wamethibitishwa • ${data.counts.pendingVerification} wanasubiri`} />
              <CountCard label="Oda zote" value={data.counts.totalOrders}
                sub={`Mpya (siku ${data.days}): ${data.counts.newOrdersInRange}`} />
              <CountCard label="Oda zinazoendelea" value={data.counts.activeOrders}
                sub={`${data.counts.completedOrders} zimekamilika • ${data.counts.disputedOrders} migogoro`} />
            </div>
          </section>

          <div className="grid grid-cols-1 xl:grid-cols-2 gap-4">
            <ChartCard title={`Mapato na ada ya platform (siku ${data.days})`}>
              <ResponsiveContainer width="100%" height="100%">
                <AreaChart data={daily}>
                  <CartesianGrid strokeDasharray="3 3" stroke="#eee" />
                  <XAxis dataKey="label" fontSize={11} />
                  <YAxis fontSize={11} tickFormatter={(v) => shortTsh(Number(v))} />
                  <Tooltip formatter={(v) => tsh(Number(v))} />
                  <Legend />
                  <Area type="monotone" dataKey="revenue" name="Malipo ya wateja" stroke="#0B3B3E" fill="#0B3B3E33" />
                  <Area type="monotone" dataKey="platformFee" name="Ada ya platform" stroke="#F07F2B" fill="#F07F2B33" />
                </AreaChart>
              </ResponsiveContainer>
            </ChartCard>

            <ChartCard title={`Oda mpya na watumiaji wapya (siku ${data.days})`}>
              <ResponsiveContainer width="100%" height="100%">
                <BarChart data={daily}>
                  <CartesianGrid strokeDasharray="3 3" stroke="#eee" />
                  <XAxis dataKey="label" fontSize={11} />
                  <YAxis fontSize={11} allowDecimals={false} />
                  <Tooltip />
                  <Legend />
                  <Bar dataKey="orders" name="Oda" fill="#0B3B3E" radius={[4, 4, 0, 0]} />
                  <Bar dataKey="newUsers" name="Watumiaji wapya" fill="#F07F2B" radius={[4, 4, 0, 0]} />
                </BarChart>
              </ResponsiveContainer>
            </ChartCard>

            <ChartCard title="Oda kwa hali">
              {statusData.length === 0 ? (
                <div className="h-full flex items-center justify-center text-gray-400">Bado hakuna oda</div>
              ) : (
                <ResponsiveContainer width="100%" height="100%">
                  <PieChart>
                    <Pie data={statusData} dataKey="count" nameKey="label" outerRadius={100} label>
                      {statusData.map((_, i) => (
                        <Cell key={i} fill={PIE_COLORS[i % PIE_COLORS.length]} />
                      ))}
                    </Pie>
                    <Tooltip />
                    <Legend />
                  </PieChart>
                </ResponsiveContainer>
              )}
            </ChartCard>

            <ChartCard title="Malipo kwa mtandao">
              {providerData.length === 0 ? (
                <div className="h-full flex items-center justify-center text-gray-400">Bado hakuna malipo</div>
              ) : (
                <ResponsiveContainer width="100%" height="100%">
                  <BarChart data={providerData} layout="vertical">
                    <CartesianGrid strokeDasharray="3 3" stroke="#eee" />
                    <XAxis type="number" fontSize={11} tickFormatter={(v) => shortTsh(Number(v))} />
                    <YAxis type="category" dataKey="label" width={100} fontSize={12} />
                    <Tooltip formatter={(v) => tsh(Number(v))} />
                    <Bar dataKey="amount" name="Kiasi" fill="#059669" radius={[0, 4, 4, 0]} />
                  </BarChart>
                </ResponsiveContainer>
              )}
            </ChartCard>
          </div>

          <section className="bg-white rounded-2xl shadow-sm overflow-hidden">
            <h3 className="font-bold p-5 pb-3">Wabunifu 10 bora (kwa mapato)</h3>
            <table className="w-full text-sm">
              <thead className="bg-gray-50 text-gray-500 text-left">
                <tr>
                  <th className="px-5 py-3 font-semibold">#</th>
                  <th className="px-5 py-3 font-semibold">Mbunifu</th>
                  <th className="px-5 py-3 font-semibold text-right">Oda zilizokamilika</th>
                  <th className="px-5 py-3 font-semibold text-right">Mapato</th>
                </tr>
              </thead>
              <tbody>
                {data.topDesigners.length === 0 ? (
                  <tr>
                    <td colSpan={4} className="px-5 py-8 text-center text-gray-400">
                      Bado hakuna oda zilizokamilika
                    </td>
                  </tr>
                ) : (
                  data.topDesigners.map((d, i) => (
                    <tr key={d.designerId} className="border-t">
                      <td className="px-5 py-3 text-gray-400">{i + 1}</td>
                      <td className="px-5 py-3 font-semibold">{d.name}</td>
                      <td className="px-5 py-3 text-right">{d.completedOrders}</td>
                      <td className="px-5 py-3 text-right font-bold text-emerald-600">{tsh(d.earnings)}</td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </section>
        </>
      )}
    </div>
  );
}
