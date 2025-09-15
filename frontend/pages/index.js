import { useState, useEffect } from 'react';
import Head from 'next/head';
import { Activity, Shield, TrendingUp, AlertCircle, CheckCircle, Clock, DollarSign, Users } from 'lucide-react';

export default function Dashboard() {
  const [metrics, setMetrics] = useState({
    nav: 1.0425,
    oracleAge: 2.3,
    ltvHeadroom: 23.7,
    totalValue: 2847293,
    compliance: 'operational',
    oracle: 'operational',
    ipfs: 'operational'
  });

  const [loading, setLoading] = useState(true);

  useEffect(() => {
    // Simulate loading and data fetching
    const timer = setTimeout(() => setLoading(false), 1500);
    return () => clearTimeout(timer);
  }, []);

  const formatCurrency = (value) => {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD',
      minimumFractionDigits: 0,
      maximumFractionDigits: 0,
    }).format(value);
  };

  const StatusIndicator = ({ status, label }) => {
    const statusConfig = {
      operational: { color: 'status-green', icon: CheckCircle, text: 'Operational' },
      warning: { color: 'status-yellow', icon: AlertCircle, text: 'Warning' },
      error: { color: 'status-red', icon: AlertCircle, text: 'Error' }
    };

    const config = statusConfig[status] || statusConfig.error;
    const Icon = config.icon;

    return (
      <div className="flex items-center space-x-2">
        <Icon className="h-4 w-4 text-current" />
        <span className={`status-indicator ${config.color}`}>
          {config.text}
        </span>
      </div>
    );
  };

  return (
    <>
      <Head>
        <title>iYield™ Protocol Dashboard - Insurance-Backed RWA Platform</title>
        <meta name="description" content="Professional dashboard for iYield Protocol - the leading platform for tokenized insurance cash surrender values with Compliance-by-Design™" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <link rel="icon" href="/favicon.ico" />
      </Head>

      <div className="min-h-screen bg-gradient-to-br from-gray-50 to-white">
        {/* Header */}
        <header className="bg-white shadow-sm border-b border-gray-200">
          <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
            <div className="flex justify-between items-center py-6">
              <div className="flex items-center space-x-3">
                <div className="w-8 h-8 bg-iyield-600 rounded-lg flex items-center justify-center">
                  <TrendingUp className="h-5 w-5 text-white" />
                </div>
                <div>
                  <h1 className="text-2xl font-bold text-gray-900">iYield™ Protocol</h1>
                  <p className="text-sm text-gray-500">Insurance-Backed RWA Tokenization Platform</p>
                </div>
              </div>
              <div className="flex items-center space-x-4">
                <div className="text-right">
                  <p className="text-sm font-medium text-gray-900">ERC-RWA:CSV</p>
                  <p className="text-xs text-gray-500">Compliance-by-Design™</p>
                </div>
                <div className="w-10 h-10 bg-iyield-100 rounded-full flex items-center justify-center">
                  <Shield className="h-5 w-5 text-iyield-600" />
                </div>
              </div>
            </div>
          </div>
        </header>

        {/* Main Dashboard */}
        <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
          {/* Key Metrics */}
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
            <div className="metric-card">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm font-medium text-gray-600">NAV (Net Asset Value)</p>
                  <p className="text-2xl font-bold text-gray-900">
                    ${metrics.nav.toFixed(4)}
                    <span className="text-sm font-normal text-green-600 ml-2">+0.25%</span>
                  </p>
                </div>
                <div className="w-12 h-12 bg-green-100 rounded-lg flex items-center justify-center">
                  <DollarSign className="h-6 w-6 text-green-600" />
                </div>
              </div>
            </div>

            <div className="metric-card">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm font-medium text-gray-600">Oracle Age</p>
                  <p className="text-2xl font-bold text-gray-900">
                    {metrics.oracleAge.toFixed(1)}h
                    <span className="text-sm font-normal text-iyield-600 ml-2">Fresh</span>
                  </p>
                </div>
                <div className="w-12 h-12 bg-iyield-100 rounded-lg flex items-center justify-center">
                  <Clock className="h-6 w-6 text-iyield-600" />
                </div>
              </div>
            </div>

            <div className="metric-card">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm font-medium text-gray-600">LTV Headroom</p>
                  <p className="text-2xl font-bold text-gray-900">
                    {metrics.ltvHeadroom.toFixed(1)}%
                    <span className="text-sm font-normal text-green-600 ml-2">Safe</span>
                  </p>
                </div>
                <div className="w-12 h-12 bg-green-100 rounded-lg flex items-center justify-center">
                  <Shield className="h-6 w-6 text-green-600" />
                </div>
              </div>
            </div>

            <div className="metric-card">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm font-medium text-gray-600">Total Value Locked</p>
                  <p className="text-2xl font-bold text-gray-900">
                    {formatCurrency(metrics.totalValue)}
                  </p>
                </div>
                <div className="w-12 h-12 bg-purple-100 rounded-lg flex items-center justify-center">
                  <TrendingUp className="h-6 w-6 text-purple-600" />
                </div>
              </div>
            </div>
          </div>

          {/* System Status */}
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-8 mb-8">
            <div className="card">
              <h3 className="text-lg font-semibold text-gray-900 mb-4">System Status</h3>
              <div className="space-y-4">
                <div className="flex items-center justify-between py-2">
                  <span className="text-sm font-medium text-gray-700">Compliance Registry</span>
                  <StatusIndicator status={metrics.compliance} />
                </div>
                <div className="flex items-center justify-between py-2">
                  <span className="text-sm font-medium text-gray-700">Proof-of-CSV™ Oracle</span>
                  <StatusIndicator status={metrics.oracle} />
                </div>
                <div className="flex items-center justify-between py-2">
                  <span className="text-sm font-medium text-gray-700">IPFS Attestation</span>
                  <StatusIndicator status={metrics.ipfs} />
                </div>
              </div>
            </div>

            <div className="card">
              <h3 className="text-lg font-semibold text-gray-900 mb-4">Protocol Features</h3>
              <div className="space-y-3">
                <div className="flex items-center space-x-3">
                  <CheckCircle className="h-5 w-5 text-green-500" />
                  <span className="text-sm text-gray-700">ERC-RWA:CSV Standard</span>
                </div>
                <div className="flex items-center space-x-3">
                  <CheckCircle className="h-5 w-5 text-green-500" />
                  <span className="text-sm text-gray-700">Multi-Attestor Consensus</span>
                </div>
                <div className="flex items-center space-x-3">
                  <CheckCircle className="h-5 w-5 text-green-500" />
                  <span className="text-sm text-gray-700">Automated LTV Enforcement</span>
                </div>
                <div className="flex items-center space-x-3">
                  <CheckCircle className="h-5 w-5 text-green-500" />
                  <span className="text-sm text-gray-700">Regulatory Compliance Gates</span>
                </div>
              </div>
            </div>
          </div>

          {/* Tranche Analytics */}
          <div className="card mb-8">
            <h3 className="text-lg font-semibold text-gray-900 mb-6">Liquidity Pool Analytics</h3>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
              <div>
                <h4 className="text-md font-medium text-gray-700 mb-4">Senior Tranche (70%)</h4>
                <div className="space-y-3">
                  <div className="flex justify-between">
                    <span className="text-sm text-gray-600">Total Deposits</span>
                    <span className="text-sm font-medium text-gray-900">$1,994,105</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-sm text-gray-600">Current APY</span>
                    <span className="text-sm font-medium text-green-600">4.2%</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-sm text-gray-600">Risk Level</span>
                    <span className="status-indicator status-green">Low</span>
                  </div>
                </div>
              </div>
              <div>
                <h4 className="text-md font-medium text-gray-700 mb-4">Junior Tranche (30%)</h4>
                <div className="space-y-3">
                  <div className="flex justify-between">
                    <span className="text-sm text-gray-600">Total Deposits</span>
                    <span className="text-sm font-medium text-gray-900">$853,188</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-sm text-gray-600">Current APY</span>
                    <span className="text-sm font-medium text-iyield-600">6.7%</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-sm text-gray-600">Risk Level</span>
                    <span className="status-indicator status-yellow">Medium</span>
                  </div>
                </div>
              </div>
            </div>
          </div>

          {/* Intellectual Property */}
          <div className="card">
            <h3 className="text-lg font-semibold text-gray-900 mb-4">Intellectual Property & Standards</h3>
            <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
              <div className="text-center">
                <div className="w-12 h-12 bg-blue-100 rounded-lg flex items-center justify-center mx-auto mb-3">
                  <Shield className="h-6 w-6 text-blue-600" />
                </div>
                <h4 className="text-sm font-semibold text-gray-900">iYield™</h4>
                <p className="text-xs text-gray-600 mt-1">Trademark pending</p>
              </div>
              <div className="text-center">
                <div className="w-12 h-12 bg-green-100 rounded-lg flex items-center justify-center mx-auto mb-3">
                  <Activity className="h-6 w-6 text-green-600" />
                </div>
                <h4 className="text-sm font-semibold text-gray-900">Proof-of-CSV™</h4>
                <p className="text-xs text-gray-600 mt-1">Patent pending</p>
              </div>
              <div className="text-center">
                <div className="w-12 h-12 bg-purple-100 rounded-lg flex items-center justify-center mx-auto mb-3">
                  <Users className="h-6 w-6 text-purple-600" />
                </div>
                <h4 className="text-sm font-semibold text-gray-900">Compliance-by-Design™</h4>
                <p className="text-xs text-gray-600 mt-1">Trademark pending</p>
              </div>
            </div>
          </div>
        </main>

        {/* Footer */}
        <footer className="bg-gray-50 border-t border-gray-200">
          <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
            <div className="text-center">
              <p className="text-sm text-gray-600">
                © 2024 iYield Protocol. All rights reserved. 
                <span className="mx-2">•</span>
                Built with Compliance-by-Design™
                <span className="mx-2">•</span>
                v0.1.0
              </p>
            </div>
          </div>
        </footer>
      </div>
    </>
  );
}