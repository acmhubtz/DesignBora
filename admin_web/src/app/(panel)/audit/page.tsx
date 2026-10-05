"use client";

import { useEffect, useState } from "react";
import { api, formatDate, type AuditLog } from "@/lib/api";

const ACTION_LABELS: Record<string, { label: string; style: string }> = {
  ADMIN_LOGIN: { label: "Kuingia", style: "bg-blue-100 text-blue-700" },
  ADMIN_LOGIN_FAILED: { label: "Kuingia kumeshindwa", style: "bg-red-100 text-red-700" },
  ADMIN_2FA_ENABLED: { label: "2FA imewashwa", style: "bg-purple-100 text-purple-700" },
  DESIGNER_APPROVED: { label: "Mbunifu amethibitishwa", style: "bg-emerald-100 text-emerald-700" },
  DESIGNER_REJECTED: { label: "Mbunifu amekataliwa", style: "bg-orange-100 text-orange-700" },
  REPORT_DOWNLOADED: { label: "Ripoti imepakuliwa", style: "bg-gray-100 text-gray-700" },
};

export default function AuditPage() {
  const [logs, setLogs] = useState<AuditLog[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    api<AuditLog[]>("admin/audit-logs")
      .then(setLogs)
      .catch((e) => setError(e instanceof Error ? e.message : "Imeshindwa kupakia"))
      .finally(() => setLoading(false));
  }, []);

  return (
    <div className="max-w-6xl">
      <h1 className="text-2xl font-extrabold">Kumbukumbu za Admin</h1>
      <p className="text-sm text-gray-500 mb-6">Vitendo 200 vya mwisho vya wasimamizi</p>

      {error && <div className="mb-4 rounded-xl bg-red-50 text-red-700 px-4 py-3 text-sm">{error}</div>}

      <div className="bg-white rounded-2xl shadow-sm overflow-hidden">
        <table className="w-full text-sm">
          <thead className="bg-gray-50 text-gray-500 text-left">
            <tr>
              <th className="px-4 py-3 font-semibold">Muda</th>
              <th className="px-4 py-3 font-semibold">Kitendo</th>
              <th className="px-4 py-3 font-semibold hidden md:table-cell">Admin</th>
              <th className="px-4 py-3 font-semibold hidden md:table-cell">Lengo</th>
              <th className="px-4 py-3 font-semibold hidden lg:table-cell">Maelezo</th>
              <th className="px-4 py-3 font-semibold hidden lg:table-cell">IP</th>
            </tr>
          </thead>
          <tbody>
            {loading ? (
              <tr>
                <td colSpan={6} className="px-4 py-10 text-center text-gray-400">
                  Inapakia...
                </td>
              </tr>
            ) : logs.length === 0 ? (
              <tr>
                <td colSpan={6} className="px-4 py-10 text-center text-gray-400">
                  Bado hakuna kumbukumbu
                </td>
              </tr>
            ) : (
              logs.map((log) => {
                const action = ACTION_LABELS[log.action] ?? { label: log.action, style: "bg-gray-100 text-gray-700" };
                return (
                  <tr key={log.id} className="border-t">
                    <td className="px-4 py-3 whitespace-nowrap text-gray-500">{formatDate(log.createdAt)}</td>
                    <td className="px-4 py-3">
                      <span className={`px-2.5 py-1 rounded-full text-xs font-semibold ${action.style}`}>
                        {action.label}
                      </span>
                    </td>
                    <td className="px-4 py-3 hidden md:table-cell">{log.adminPhone ?? "-"}</td>
                    <td className="px-4 py-3 hidden md:table-cell">
                      {log.targetType ? `${log.targetType} #${log.targetId}` : "-"}
                    </td>
                    <td className="px-4 py-3 hidden lg:table-cell text-gray-600">{log.details ?? "-"}</td>
                    <td className="px-4 py-3 hidden lg:table-cell font-mono text-xs text-gray-500">
                      {log.ipAddress ?? "-"}
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
