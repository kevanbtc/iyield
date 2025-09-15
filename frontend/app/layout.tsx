import './globals.css'
import type { Metadata } from 'next'

export const metadata: Metadata = {
  title: 'iYield Protocol™ - Insurance Asset Tokenization',
  description: 'The future of insurance-backed asset tokenization with Proof-of-CSV™ and Compliance-by-Design™',
  keywords: ['DeFi', 'Insurance', 'Tokenization', 'RWA', 'CSV', 'Blockchain', 'Compliance'],
  authors: [{ name: 'iYield Protocol Team' }],
  creator: 'iYield Protocol',
  publisher: 'iYield Protocol',
  robots: 'index, follow',
  openGraph: {
    title: 'iYield Protocol™',
    description: 'Insurance Cash Surrender Value Tokenization Platform',
    type: 'website',
    locale: 'en_US',
  },
  twitter: {
    card: 'summary_large_image',
    title: 'iYield Protocol™',
    description: 'The future of insurance-backed asset tokenization',
    creator: '@iYieldProtocol',
  },
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en">
      <body className="bg-gray-50 font-sans antialiased">
        <div className="min-h-screen">
          {children}
        </div>
      </body>
    </html>
  )
}