import type { Metadata } from "next";
import { Cairo } from "next/font/google";
import "./globals.css";
import DashboardLayout from "@/components/DashboardLayout";

const cairo = Cairo({ subsets: ["arabic", "latin"] });

export const metadata: Metadata = {
  title: "حلقتي - لوحة التحكم",
  description: "لوحة تحكم حلقة القرآن الكريم",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="ar" dir="rtl">
      <body className={cairo.className}>
        <DashboardLayout>
          {children}
        </DashboardLayout>
      </body>
    </html>
  );
}