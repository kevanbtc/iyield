/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  swcMinify: true,
  env: {
    NEXT_PUBLIC_NETWORK: process.env.NEXT_PUBLIC_NETWORK || 'sepolia',
    NEXT_PUBLIC_IYIELD_TOKEN: process.env.NEXT_PUBLIC_IYIELD_TOKEN || '',
    NEXT_PUBLIC_VAULT: process.env.NEXT_PUBLIC_VAULT || '',
    NEXT_PUBLIC_ORACLE: process.env.NEXT_PUBLIC_ORACLE || '',
    NEXT_PUBLIC_POOL: process.env.NEXT_PUBLIC_POOL || '',
    NEXT_PUBLIC_COMPLIANCE_REGISTRY: process.env.NEXT_PUBLIC_COMPLIANCE_REGISTRY || '',
    NEXT_PUBLIC_IPFS_GATEWAY: process.env.NEXT_PUBLIC_IPFS_GATEWAY || 'https://ipfs.io/ipfs/',
  },
  // Enable static exports for deployment
  output: 'export',
  trailingSlash: true,
  images: {
    unoptimized: true
  }
}

module.exports = nextConfig