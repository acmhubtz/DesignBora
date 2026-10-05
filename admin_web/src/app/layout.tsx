import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "DesignBora Admin",
  description: "Admin Panel ya DesignBora",
  robots: { index: false, follow: false },
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="sw">
      <body className="antialiased">{children}</body>
    </html>
  );
}
