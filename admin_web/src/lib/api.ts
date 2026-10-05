export type DocumentItem = {
  id: number;
  documentType: string;
  status: string;
  uploadedAt: string | null;
  extension: string;
};

export type DesignerItem = {
  designerId: number;
  fullName: string;
  phone: string;
  email: string | null;
  avatarUrl: string | null;
  accountType: string | null;
  companyName: string | null;
  companyRegNumber: string | null;
  verificationStatus: string;
  verificationNote: string | null;
  createdAt: string | null;
  documents: DocumentItem[];
};

export type Stats = { pending: number; verified: number; rejected: number };

export type AuditLog = {
  id: number;
  adminUserId: number | null;
  adminPhone: string | null;
  action: string;
  targetType: string | null;
  targetId: number | null;
  details: string | null;
  ipAddress: string | null;
  createdAt: string;
};

/** Ombi kwa backend kupitia proxy ya Next.js (/api/backend/...) */
export async function api<T>(path: string, init?: RequestInit): Promise<T> {
  const res = await fetch(`/api/backend/${path}`, {
    ...init,
    headers: { "Content-Type": "application/json", ...(init?.headers ?? {}) },
    cache: "no-store",
  });
  const json = await res.json().catch(() => ({}));

  // 401, au 403 bila ujumbe = token imeisha muda -> rudi kwenye login
  if (res.status === 401 || (res.status === 403 && !json.message)) {
    window.location.href = "/login";
    throw new Error("Ingia tena");
  }
  if (!res.ok) {
    throw new Error(json.message ?? `Hitilafu (${res.status})`);
  }
  return json.data as T;
}

export function documentTypeLabel(type: string): string {
  switch (type) {
    case "NATIONAL_ID":
      return "Kitambulisho (NIDA / Mpiga Kura / Pasipoti)";
    case "BUSINESS_LICENSE":
      return "Leseni ya Biashara / BRELA";
    case "TIN_CERTIFICATE":
      return "Cheti cha TIN (TRA)";
    default:
      return "Nyaraka Nyingine";
  }
}

export function accountTypeLabel(type: string | null): string {
  if (type === "COMPANY") return "Kampuni";
  if (type === "INDIVIDUAL") return "Mtu Binafsi";
  return "-";
}

export function formatDate(value?: string | null): string {
  if (!value) return "-";
  const date = new Date(value);
  return isNaN(date.getTime())
    ? value
    : date.toLocaleString("sw-TZ", { dateStyle: "medium", timeStyle: "short" });
}
