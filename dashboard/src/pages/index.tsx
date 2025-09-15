import React from 'react';

export default function Dashboard() {
  return (
    <div className="min-h-screen bg-gray-100">
      {/* Header */}
      <header className="bg-white shadow-sm border-b">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between items-center py-6">
            <div className="flex items-center">
              <h1 className="text-2xl font-bold text-gray-900">iYield Protocol™</h1>
              <span className="ml-2 text-sm text-gray-500">Infrastructure Standard for Insurance-Backed RWAs</span>
            </div>
            <button className="bg-blue-600 text-white px-4 py-2 rounded-md hover:bg-blue-700">
              Connect Wallet
            </button>
          </div>
        </div>
      </header>

      {/* Main Content */}
      <main className="max-w-7xl mx-auto py-6 sm:px-6 lg:px-8">
        {/* Stats Overview */}
        <div className="grid grid-cols-1 md:grid-cols-4 gap-6 mb-8">
          <div className="bg-white overflow-hidden shadow rounded-lg">
            <div className="p-5">
              <div className="flex items-center">
                <div className="flex-shrink-0">
                  <div className="w-8 h-8 bg-blue-500 rounded-md flex items-center justify-center">
                    <span className="text-white font-semibold">$</span>
                  </div>
                </div>
                <div className="ml-5 w-0 flex-1">
                  <dl>
                    <dt className="text-sm font-medium text-gray-500 truncate">Total NAV</dt>
                    <dd className="text-lg font-medium text-gray-900">$2.4M</dd>
                  </dl>
                </div>
              </div>
            </div>
          </div>

          <div className="bg-white overflow-hidden shadow rounded-lg">
            <div className="p-5">
              <div className="flex items-center">
                <div className="flex-shrink-0">
                  <div className="w-8 h-8 bg-green-500 rounded-md flex items-center justify-center">
                    <span className="text-white font-semibold">✓</span>
                  </div>
                </div>
                <div className="ml-5 w-0 flex-1">
                  <dl>
                    <dt className="text-sm font-medium text-gray-500 truncate">Compliant Policies</dt>
                    <dd className="text-lg font-medium text-gray-900">147</dd>
                  </dl>
                </div>
              </div>
            </div>
          </div>

          <div className="bg-white overflow-hidden shadow rounded-lg">
            <div className="p-5">
              <div className="flex items-center">
                <div className="flex-shrink-0">
                  <div className="w-8 h-8 bg-yellow-500 rounded-md flex items-center justify-center">
                    <span className="text-white font-semibold">%</span>
                  </div>
                </div>
                <div className="ml-5 w-0 flex-1">
                  <dl>
                    <dt className="text-sm font-medium text-gray-500 truncate">Avg LTV</dt>
                    <dd className="text-lg font-medium text-gray-900">72.3%</dd>
                  </dl>
                </div>
              </div>
            </div>
          </div>

          <div className="bg-white overflow-hidden shadow rounded-lg">
            <div className="p-5">
              <div className="flex items-center">
                <div className="flex-shrink-0">
                  <div className="w-8 h-8 bg-purple-500 rounded-md flex items-center justify-center">
                    <span className="text-white font-semibold">⚡</span>
                  </div>
                </div>
                <div className="ml-5 w-0 flex-1">
                  <dl>
                    <dt className="text-sm font-medium text-gray-500 truncate">Oracle Freshness</dt>
                    <dd className="text-lg font-medium text-gray-900">4.2h</dd>
                  </dl>
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* Protocol Status */}
        <div className="bg-white shadow rounded-lg mb-8">
          <div className="px-4 py-5 sm:p-6">
            <h3 className="text-lg leading-6 font-medium text-gray-900 mb-4">
              ERC-RWA:CSV Protocol Status
            </h3>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              <div>
                <h4 className="text-sm font-medium text-gray-500 mb-2">Compliance Features</h4>
                <ul className="space-y-1">
                  <li className="flex items-center text-sm text-gray-700">
                    <span className="text-green-500 mr-2">✅</span>
                    Compliance-by-Design™ Active
                  </li>
                  <li className="flex items-center text-sm text-gray-700">
                    <span className="text-green-500 mr-2">✅</span>
                    KYC/AML Whitelisting
                  </li>
                  <li className="flex items-center text-sm text-gray-700">
                    <span className="text-green-500 mr-2">✅</span>
                    Rule 144 Enforcement
                  </li>
                </ul>
              </div>
              <div>
                <h4 className="text-sm font-medium text-gray-500 mb-2">Risk Controls</h4>
                <ul className="space-y-1">
                  <li className="flex items-center text-sm text-gray-700">
                    <span className="text-green-500 mr-2">✅</span>
                    Proof-of-CSV™ Oracle Active
                  </li>
                  <li className="flex items-center text-sm text-gray-700">
                    <span className="text-green-500 mr-2">✅</span>
                    Auto LTV Ratchets
                  </li>
                  <li className="flex items-center text-sm text-gray-700">
                    <span className="text-green-500 mr-2">✅</span>
                    Emergency Safeguards
                  </li>
                </ul>
              </div>
            </div>
          </div>
        </div>

        {/* Footer */}
        <div className="text-center text-sm text-gray-500">
          <p>
            <strong>iYield Protocol™</strong> — Created Here. Owned Here. Standardized Here.
          </p>
          <p className="mt-1">
            The Infrastructure Standard for Insurance-Backed RWAs
          </p>
        </div>
      </main>
    </div>
  );
}