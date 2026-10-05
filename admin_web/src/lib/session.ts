/** Jina la cookie ya httpOnly inayobeba token ya admin (server tu) */
export const ADMIN_COOKIE = "db_admin";

/** Anwani ya backend - inasomwa upande wa server tu (haionekani kwa kivinjari) */
export function backendUrl(): string {
  return (process.env.BACKEND_URL ?? "http://localhost:8080").replace(/\/$/, "");
}
