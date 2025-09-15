'use client'

import { Shield, TrendingUp, Users, AlertCircle, CheckCircle, Clock } from 'lucide-react'

export default function HomePage() {
  return (
    <div className="min-h-screen">
      {/* Header */}
      <header className="bg-white border-b border-gray-200">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between items-center h-16">
            <div className="flex items-center">
              <h1 className="text-2xl font-bold text-gray-900">
                iYield Protocol™
              </h1>
              <span className="ml-2 text-sm text-gray-500">
                Insurance Asset Tokenization
              </span>
            </div>
            <div className="flex items-center space-x-4">
              <div className="flex items-center space-x-2">
                <CheckCircle className="h-4 w-4 text-green-500" />
                <span className="text-sm text-gray-600">System Operational</span>
              </div>
            </div>
          </div>
        </div>
      </header>

      {/* Main Content */}
      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {/* Hero Section */}
        <div className="text-center mb-12">
          <h2 className="text-4xl font-bold text-gray-900 mb-4">
            The Future of Insurance-Backed Asset Tokenization
          </h2>
          <p className="text-xl text-gray-600 max-w-3xl mx-auto">
            Unlock $2.7 trillion in insurance cash surrender values through our patent-pending 
            <strong className="text-primary-600"> Proof-of-CSV™</strong> system and 
            <strong className="text-primary-600"> Compliance-by-Design™</strong> architecture.
          </p>
        </div>

        {/* Status Cards */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-12">
          <div className="stat-card">
            <div className="flex items-center">
              <Shield className="h-8 w-8 text-green-500" />
              <div className="ml-4">
                <h3 className="text-lg font-semibold text-gray-900">Oracle Status</h3>
                <p className="text-sm text-gray-600">Proof-of-CSV™ Active</p>
                <p className="text-2xl font-bold text-green-600">Operational</p>
              </div>
            </div>
          </div>

          <div className="stat-card">
            <div className="flex items-center">
              <CheckCircle className="h-8 w-8 text-blue-500" />
              <div className="ml-4">
                <h3 className="text-lg font-semibold text-gray-900">Compliance</h3>
                <p className="text-sm text-gray-600">Automated KYC/AML</p>
                <p className="text-2xl font-bold text-blue-600">100% Verified</p>
              </div>
            </div>
          </div>

          <div className="stat-card">
            <div className="flex items-center">
              <TrendingUp className="h-8 w-8 text-purple-500" />
              <div className="ml-4">
                <h3 className="text-lg font-semibold text-gray-900">Total Value Locked</h3>
                <p className="text-sm text-gray-600">CSV Assets</p>
                <p className="text-2xl font-bold text-purple-600">$0</p>
              </div>
            </div>
          </div>
        </div>

        {/* Protocol Features */}
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-8 mb-12">
          <div className="card p-8">
            <h3 className="text-2xl font-bold text-gray-900 mb-4">
              🏦 Proof-of-CSV™ Oracle System
            </h3>
            <ul className="space-y-3 text-gray-600">
              <li className="flex items-start">
                <CheckCircle className="h-5 w-5 text-green-500 mt-0.5 mr-2 flex-shrink-0" />
                Multi-party attestation with 2-of-3 consensus
              </li>
              <li className="flex items-start">
                <CheckCircle className="h-5 w-5 text-green-500 mt-0.5 mr-2 flex-shrink-0" />
                Cryptographic verification via Merkle proofs
              </li>
              <li className="flex items-start">
                <CheckCircle className="h-5 w-5 text-green-500 mt-0.5 mr-2 flex-shrink-0" />
                Real-time carrier credit rating integration
              </li>
              <li className="flex items-start">
                <CheckCircle className="h-5 w-5 text-green-500 mt-0.5 mr-2 flex-shrink-0" />
                IPFS-based transparency and audit trails
              </li>
            </ul>
          </div>

          <div className="card p-8">
            <h3 className="text-2xl font-bold text-gray-900 mb-4">
              🔒 Compliance-by-Design™
            </h3>
            <ul className="space-y-3 text-gray-600">
              <li className="flex items-start">
                <CheckCircle className="h-5 w-5 text-green-500 mt-0.5 mr-2 flex-shrink-0" />
                Automated Regulation D/S compliance
              </li>
              <li className="flex items-start">
                <CheckCircle className="h-5 w-5 text-green-500 mt-0.5 mr-2 flex-shrink-0" />
                Real-time KYC/AML verification
              </li>
              <li className="flex items-start">
                <CheckCircle className="h-5 w-5 text-green-500 mt-0.5 mr-2 flex-shrink-0" />
                Rule 144 lockup period enforcement
              </li>
              <li className="flex items-start">
                <CheckCircle className="h-5 w-5 text-green-500 mt-0.5 mr-2 flex-shrink-0" />
                Geographic access controls
              </li>
            </ul>
          </div>
        </div>

        {/* Market Stats */}
        <div className="card p-8 mb-12">
          <h3 className="text-2xl font-bold text-gray-900 mb-6">Market Opportunity</h3>
          <div className="grid grid-cols-1 md:grid-cols-4 gap-6">
            <div className="text-center">
              <p className="text-3xl font-bold text-primary-600">$2.7T</p>
              <p className="text-sm text-gray-600">Total U.S. CSV Assets</p>
            </div>
            <div className="text-center">
              <p className="text-3xl font-bold text-accent-600">4-8%</p>
              <p className="text-sm text-gray-600">Target Yield Range</p>
            </div>
            <div className="text-center">
              <p className="text-3xl font-bold text-purple-600">80%</p>
              <p className="text-sm text-gray-600">Maximum LTV Ratio</p>
            </div>
            <div className="text-center">
              <p className="text-3xl font-bold text-orange-600">24/7</p>
              <p className="text-sm text-gray-600">Instant Liquidity</p>
            </div>
          </div>
        </div>

        {/* Patent & IP Section */}
        <div className="card p-8 mb-12 bg-gradient-to-r from-blue-50 to-purple-50">
          <h3 className="text-2xl font-bold text-gray-900 mb-4">
            🏆 Patent-Defensible Innovation
          </h3>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div>
              <h4 className="font-semibold text-gray-900 mb-2">Trademark Protection</h4>
              <ul className="space-y-1 text-gray-600">
                <li>• iYield™ Protocol</li>
                <li>• Proof-of-CSV™ Oracle System</li>
                <li>• Compliance-by-Design™ Framework</li>
                <li>• ERC-RWA:CSV™ Token Standard</li>
              </ul>
            </div>
            <div>
              <h4 className="font-semibold text-gray-900 mb-2">Patent Applications</h4>
              <ul className="space-y-1 text-gray-600">
                <li>• Tokenized insurance-backed credit system</li>
                <li>• Multi-oracle attestation for RWA valuations</li>
                <li>• Compliance-integrated token transfers</li>
                <li>• CSV oracle consensus mechanisms</li>
              </ul>
            </div>
          </div>
        </div>

        {/* Important Notices */}
        <div className="card p-6 bg-yellow-50 border-yellow-200">
          <div className="flex">
            <AlertCircle className="h-5 w-5 text-yellow-500 mt-0.5 mr-3 flex-shrink-0" />
            <div>
              <h4 className="font-semibold text-yellow-800">Important Notice</h4>
              <p className="text-sm text-yellow-700 mt-1">
                iYield tokens constitute securities under U.S. law. This offering is limited to accredited investors only. 
                Please consult with qualified legal and financial professionals before participating.
              </p>
            </div>
          </div>
        </div>
      </main>

      {/* Footer */}
      <footer className="bg-gray-900 text-white py-12">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="text-center">
            <h3 className="text-xl font-bold mb-2">iYield Protocol™</h3>
            <p className="text-gray-400 mb-4">
              Unlocking the future of insurance asset tokenization through compliance innovation and technical excellence.
            </p>
            <p className="text-sm text-gray-500">
              Patent Pending • Built with ❤️ by the iYield Protocol Team
            </p>
          </div>
        </div>
      </footer>
    </div>
  )
}