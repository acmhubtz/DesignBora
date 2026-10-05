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

// ---------- Takwimu (analytics) ----------

export type MoneySummary = {
  totalCollected: number;
  escrowHeld: number;
  platformFeesEarned: number;
  platformFeesPending: number;
  paidToDesigners: number;
  payoutsPending: number;
  payoutsFailed: number;
};

export type CountSummary = {
  customers: number;
  designers: number;
  verifiedDesigners: number;
  pendingVerification: number;
  totalOrders: number;
  activeOrders: number;
  completedOrders: number;
  disputedOrders: number;
  newUsersInRange: number;
  newOrdersInRange: number;
};

export type DayPoint = {
  date: string;
  revenue: number;
  platformFee: number;
  orders: number;
  payments: number;
  newUsers: number;
};

export type NamedValue = { name: string; count: number; amount: number };

export type TopDesigner = { designerId: number; name: string; completedOrders: number; earnings: number };

export type Overview = {
  days: number;
  money: MoneySummary;
  counts: CountSummary;
  daily: DayPoint[];
  ordersByStatus: NamedValue[];
  paymentsByProvider: NamedValue[];
  topDesigners: TopDesigner[];
};

export type DesignerActivity = {
  designerId: number;
  name: string;
  phone: string;
  verificationStatus: string;
  registeredAt: string | null;
  totalOrders: number;
  activeOrders: number;
  completedOrders: number;
  disputedOrders: number;
  grossSales: number;
  earnings: number;
  paidOut: number;
  pendingPayout: number;
  lastOrderAt: string | null;
  payoutMethod: string | null;
};

export function tsh(value: number | null | undefined): string {
  return `TSh ${new Intl.NumberFormat("en-US", { maximumFractionDigits: 0 }).format(Number(value ?? 0))}`;
}

export function shortTsh(value: number): string {
  if (value >= 1_000_000) return `${(value / 1_000_000).toFixed(1)}M`;
  if (value >= 1_000) return `${(value / 1_000).toFixed(0)}K`;
  return String(Math.round(value));
}

export const ORDER_STATUS_LABELS: Record<string, string> = {
  PENDING_PAYMENT: "Haijalipwa",
  PAID: "Imelipwa",
  IN_PROGRESS: "Inaendelea",
  DRAFT_SUBMITTED: "Draft Imetumwa",
  COMPLETED: "Imekamilika",
  DISPUTED: "Mgogoro",
};

export const PROVIDER_LABELS: Record<string, string> = {
  MPESA: "M-Pesa",
  MIXX: "Mixx by Yas",
  AIRTEL: "Airtel Money",
  HALOPESA: "HaloPesa",
  TPESA: "T-Pesa",
  CARD: "Kadi",
  MOBILE: "Simu",
};
