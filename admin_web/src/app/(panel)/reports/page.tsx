"use client";

import { useState } from "react";

function isoDate(d: Date): string {
  return d.toISOString().slice(0, 10);
}

const PRESETS = [
  { label: "Siku 7", days: 7 },
  { label: "Siku 30", days: 30 },
  { label: "Siku 90", days: 90 },
  { label: "Mwaka", days: 365 },
];

export default function ReportsPage() {
  const today = new Date();
  const [to, setTo] = useState(isoDate(today));
  const [from, setFrom] = useState(isoDate(new Date(today.getTime() - 29 * 86_400_000)));

  function applyPreset(days: number) {
    const end = new Date();
    setTo(isoDate(end));
    setFrom(isoDate(new Date(end.getTime() - (days - 1) * 86_400_000)));
  }

  const downloadUrl = `/api/backend/admin/analytics/report.csv?from=${from}&to=${to}`;

  return (
    <div className="max-w-3xl">
      <h1 className="text-2xl font-extrabold">Ripoti</h1>
      <p className="text-sm text-gray-500 mb-6">Pakua ripoti ya oda na malipo (CSV, inafunguka kwenye Excel)</p>

      <div className="bg-white rounded-2xl shadow-sm p-6 space-y-5">
        <div className="flex flex-wrap gap-2">
          {PRESETS.map((p) => (
            <button
              key={p.days}
              onClick={() => applyPreset(p.days)}
              className="px-3 py-1.5 rounded-lg bg-gray-100 hover:bg-gray-200 text-sm font-semibold"
            >
              {p.label}
            </button>
          ))}
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <label className="block">
            <span className="block text-sm font-semibold mb-1.5">Kuanzia</span>
            <input
              type="date"
              value={from}
              max={to}
              onChange={(e) => setFrom(e.target.value)}
              className="w-full rounded-xl border border-gray-200 px-4 py-2.5"
            />
          </label>
          <label className="block">
            <span className="block text-sm font-semibold mb-1.5">Hadi</span>
            <input
              type="date"
              value={to}
              min={from}
              onChange={(e) => setTo(e.target.value)}
              className="w-full rounded-xl border border-gray-200 px-4 py-2.5"
            />
          </label>
        </div>

        <a
          href={downloadUrl}
          className="inline-flex items-center justify-center w-full rounded-xl bg-accent hover:bg-accent-dark text-white font-bold py-3"
        >
          ⬇ Pakua Ripoti (CSV)
        </a>

        <div className="text-sm text-gray-600">
          <div className="font-semibold mb-2">Ripoti inaonyesha kwa kila oda:</div>
          <ul className="list-disc pl-5 space-y-1">
            <li>Namba ya oda, tarehe, mteja, mbunifu na huduma</li>
            <li>Hali ya oda (imelipwa, inaendelea, imekamilika, mgogoro)</li>
            <li>Jumla aliyolipa mteja, ada ya platform, na anachopata mbunifu</li>
            <li>Njia ya malipo (M-Pesa, Mixx, Airtel…)</li>
            <li>Hali ya payout na mahali pesa ilipotumwa</li>
          </ul>
          <p className="mt-3 text-xs text-gray-400">Kila upakuaji wa ripoti unaandikwa kwenye Kumbukumbu za Admin.</p>
        </div>
      </div>
    </div>
  );
}
