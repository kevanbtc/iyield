import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "iYield Protocol - Insurance RWA Tokenization",
  description: "Tokenized insurance cash surrender values with on-chain compliance and Proof-of-CSV™ attestations",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body className="antialiased font-sans">
        {children}
      </body>
    </html>
  );
}
