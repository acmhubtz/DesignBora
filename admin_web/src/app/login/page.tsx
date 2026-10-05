"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { QRCodeSVG } from "qrcode.react";

type Step = "CREDENTIALS" | "SETUP" | "CODE";

export default function LoginPage() {
  const router = useRouter();
  const [phone, setPhone] = useState("+255");
  const [password, setPassword] = useState("");
  const [code, setCode] = useState("");
  const [step, setStep] = useState<Step>("CREDENTIALS");
  const [otpauthUrl, setOtpauthUrl] = useState<string | null>(null);
  const [secret, setSecret] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError(null);
    try {
      const res = await fetch("/api/auth/login", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ phone, password, code: step === "CREDENTIALS" ? null : code }),
      });
      const json = await res.json();
      if (!res.ok || !json.success) {
        setError(json.message ?? "Imeshindwa kuingia");
        return;
      }
      if (json.status === "OK") {
        router.replace("/dashboard");
        router.refresh();
        return;
      }
      if (json.status === "SETUP_REQUIRED") {
        setOtpauthUrl(json.otpauthUrl);
        setSecret(json.secret);
        setStep("SETUP");
        setCode("");
      } else if (json.status === "CODE_REQUIRED") {
        setStep("CODE");
        setCode("");
      }
    } catch {
      setError("Imeshindwa kuwasiliana na server");
    } finally {
      setLoading(false);
    }
  }

  const inputClass =
    "w-full rounded-xl border border-gray-200 bg-white px-4 py-3 outline-none focus:border-accent focus:ring-2 focus:ring-accent/20";

  return (
    <main className="min-h-screen flex items-center justify-center bg-[#141414] p-4">
      <div className="w-full max-w-md">
        <div className="text-center mb-6">
          <div className="mx-auto w-14 h-14 rounded-2xl bg-gradient-to-br from-brand to-accent flex items-center justify-center text-white text-2xl font-extrabold">
            B
          </div>
          <h1 className="mt-3 text-2xl font-extrabold text-white">DesignBora Admin</h1>
          <p className="text-sm text-white/60">Eneo la wasimamizi pekee</p>
        </div>

        <form onSubmit={submit} className="bg-white rounded-3xl p-7 shadow-2xl space-y-4">
          {step === "CREDENTIALS" && (
            <>
              <div>
                <label className="block text-sm font-semibold mb-1.5">Namba ya Simu</label>
                <input className={inputClass} value={phone} onChange={(e) => setPhone(e.target.value)} required />
              </div>
              <div>
                <label className="block text-sm font-semibold mb-1.5">Nenosiri</label>
                <input
                  className={inputClass}
                  type="password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  required
                />
              </div>
            </>
          )}

          {step === "SETUP" && otpauthUrl && (
            <div className="space-y-3">
              <h2 className="font-bold text-lg">Washa Uthibitisho wa Hatua Mbili (2FA)</h2>
              <ol className="text-sm text-gray-600 list-decimal pl-5 space-y-1">
                <li>Fungua Google Authenticator au Microsoft Authenticator kwenye simu.</li>
                <li>Skani QR code hii (au weka ufunguo hapa chini kwa mkono).</li>
                <li>Andika namba ya tarakimu 6 inayoonekana kwenye app.</li>
              </ol>
              <div className="flex justify-center p-3 bg-white border rounded-2xl">
                <QRCodeSVG value={otpauthUrl} size={190} />
              </div>
              {secret && (
                <p className="text-xs text-gray-500 break-all text-center">
                  Ufunguo: <span className="font-mono font-semibold text-gray-800">{secret}</span>
                </p>
              )}
            </div>
          )}

          {step === "CODE" && (
            <div>
              <h2 className="font-bold text-lg">Uthibitisho wa Hatua Mbili</h2>
              <p className="text-sm text-gray-600">Andika namba ya tarakimu 6 kutoka kwenye app ya Authenticator.</p>
            </div>
          )}

          {step !== "CREDENTIALS" && (
            <input
              className={`${inputClass} text-center text-2xl tracking-[0.5em] font-bold`}
              inputMode="numeric"
              autoFocus
              maxLength={6}
              placeholder="000000"
              value={code}
              onChange={(e) => setCode(e.target.value.replace(/\D/g, ""))}
              required
            />
          )}

          {error && <div className="rounded-xl bg-red-50 text-red-700 text-sm px-4 py-3">{error}</div>}

          <button
            type="submit"
            disabled={loading}
            className="w-full rounded-xl bg-accent hover:bg-accent-dark text-white font-bold py-3 disabled:opacity-60"
          >
            {loading ? "Inashughulikia..." : step === "CREDENTIALS" ? "Endelea" : "Thibitisha na Ingia"}
          </button>

          {step !== "CREDENTIALS" && (
            <button
              type="button"
              onClick={() => {
                setStep("CREDENTIALS");
                setCode("");
                setError(null);
              }}
              className="w-full text-sm text-gray-500 hover:text-gray-800"
            >
              ← Rudi mwanzo
            </button>
          )}
        </form>
      </div>
    </main>
  );
}
