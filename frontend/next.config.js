/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  swcMinify: true,
  env: {
    NEXT_PUBLIC_CHAIN_ID: process.env.NEXT_PUBLIC_CHAIN_ID || "31337",
    NEXT_PUBLIC_CSV_ORACLE_ADDRESS: process.env.NEXT_PUBLIC_CSV_ORACLE_ADDRESS || "",
    NEXT_PUBLIC_COMPLIANCE_ENGINE_ADDRESS: process.env.NEXT_PUBLIC_COMPLIANCE_ENGINE_ADDRESS || "",
    NEXT_PUBLIC_IYIELD_TOKEN_ADDRESS: process.env.NEXT_PUBLIC_IYIELD_TOKEN_ADDRESS || "",
  }
}

module.exports = nextConfig