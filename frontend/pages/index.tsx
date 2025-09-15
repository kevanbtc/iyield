import React, { useState, useEffect } from 'react';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from 'recharts';
import { Shield, Activity, TrendingUp, Users, AlertTriangle, CheckCircle, Eye, FileText, Link } from 'lucide-react';

// Mock data for demonstration - in production this would come from smart contracts
const mockData = {
  nav: [
    { time: '00:00', value: 1.000 },
    { time: '06:00', value: 1.002 },
    { time: '12:00', value: 1.005 },
    { time: '18:00', value: 1.008 },
    { time: '24:00', value: 1.012 },
  ],
  policies: [
    { id: 'POLICY_001', carrier: 'MetLife', csvValue: 100000, ltvRatio: 80, lastUpdate: new Date(), status: 'active', ipfsHash: 'QmPolicyDoc1...' },
    { id: 'POLICY_002', carrier: 'Prudential', csvValue: 250000, ltvRatio: 75, lastUpdate: new Date(), status: 'active', ipfsHash: 'QmPolicyDoc2...' },
    { id: 'POLICY_003', carrier: 'Northwestern Mutual', csvValue: 180000, ltvRatio: 85, lastUpdate: new Date(), status: 'warning', ipfsHash: 'QmPolicyDoc3...' },
  ]
};

interface DashboardCardProps {
  title: string;
  value: string;
  change: string;
  changeType: 'positive' | 'negative' | 'neutral';
  icon: React.ReactNode;
}

const DashboardCard: React.FC<DashboardCardProps> = ({ title, value, change, changeType, icon }) => {
  const changeColor = {
    positive: 'text-emerald-600',
    negative: 'text-red-600',
    neutral: 'text-gray-600'
  }[changeType];

  return (
    <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6 hover:shadow-md transition-shadow">
      <div className="flex items-center justify-between">
        <div className="flex-1">
          <p className="text-sm text-gray-600 mb-1">{title}</p>
          <p className="text-3xl font-bold text-gray-900 mb-1">{value}</p>
          <p className={`text-sm ${changeColor} font-medium`}>{change}</p>
        </div>
        <div className="w-12 h-12 bg-blue-50 rounded-xl flex items-center justify-center">
          {icon}
        </div>
      </div>
    </div>
  );
};

const StatusBadge: React.FC<{ status: string }> = ({ status }) => {
  const colors = {
    active: 'bg-emerald-100 text-emerald-800 border-emerald-200',
    warning: 'bg-amber-100 text-amber-800 border-amber-200',
    critical: 'bg-red-100 text-red-800 border-red-200'
  };

  const icons = {
    active: <CheckCircle className="w-3 h-3 mr-1" />,
    warning: <AlertTriangle className="w-3 h-3 mr-1" />,
    critical: <AlertTriangle className="w-3 h-3 mr-1" />
  };

  return (
    <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium border ${colors[status as keyof typeof colors] || colors.active}`}>
      {icons[status as keyof typeof icons]}
      {status}
    </span>
  );
};

export default function Dashboard() {
  const [currentTime, setCurrentTime] = useState(new Date());
  const [isConnected, setIsConnected] = useState(false);

  useEffect(() => {
    // Initialize time immediately to avoid hydration mismatch
    setCurrentTime(new Date());
    
    const timer = setInterval(() => {
      setCurrentTime(new Date());
    }, 1000);

    // Simulate connection status
    setIsConnected(true);

    return () => clearInterval(timer);
  }, []);

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Header */}
      <header className="bg-white border-b border-gray-200 sticky top-0 z-10">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between items-center h-16">
            <div className="flex items-center space-x-4">
              <div className="bg-blue-600 w-8 h-8 rounded-lg flex items-center justify-center">
                <Shield className="w-5 h-5 text-white" />
              </div>
              <div>
                <h1 className="text-2xl font-bold text-gray-900">iYield™ Protocol</h1>
                <p className="text-sm text-gray-500">Patent-Pending Insurance-Backed Securities Platform</p>
              </div>
            </div>
            <div className="flex items-center space-x-6">
              <div className="text-sm text-gray-600">
                Last Update: {currentTime.toLocaleTimeString()}
              </div>
              <div className="flex items-center">
                <div className={`w-2 h-2 rounded-full ${isConnected ? 'bg-emerald-500' : 'bg-red-500'}`}></div>
                <span className="ml-2 text-sm text-gray-600">
                  {isConnected ? 'Connected' : 'Disconnected'}
                </span>
              </div>
            </div>
          </div>
        </div>
      </header>

      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {/* Patent & Trademark Notice */}
        <div className="bg-gradient-to-r from-blue-50 to-indigo-50 border border-blue-200 rounded-xl p-4 mb-8">
          <div className="flex items-start space-x-3">
            <Eye className="w-5 h-5 text-blue-600 mt-0.5" />
            <div>
              <h3 className="text-sm font-semibold text-blue-900">Patent-Pending Technology Active</h3>
              <p className="text-sm text-blue-700 mt-1">
                This system implements <strong>Proof-of-CSV™</strong>, <strong>Compliance-by-Design™</strong>, 
                and <strong>automated LTV enforcement</strong> - all patent-pending innovations in the RWA insurance space.
              </p>
            </div>
          </div>
        </div>

        {/* Key Metrics */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
          <DashboardCard
            title="Net Asset Value"
            value="$1.012"
            change="+1.2% (24h)"
            changeType="positive"
            icon={<TrendingUp className="w-6 h-6 text-blue-600" />}
          />
          <DashboardCard
            title="Total CSV Value"
            value="$530,000"
            change="+2.3% (24h)"
            changeType="positive"
            icon={<Activity className="w-6 h-6 text-blue-600" />}
          />
          <DashboardCard
            title="Token Supply"
            value="425,000"
            change="No change"
            changeType="neutral"
            icon={<Users className="w-6 h-6 text-blue-600" />}
          />
          <DashboardCard
            title="Avg. LTV Ratio"
            value="80.2%"
            change="-0.5% (24h)"
            changeType="positive"
            icon={<Shield className="w-6 h-6 text-blue-600" />}
          />
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-2 gap-8 mb-8">
          {/* NAV Chart */}
          <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
            <h3 className="text-lg font-semibold text-gray-900 mb-4">NAV Performance (24h)</h3>
            <ResponsiveContainer width="100%" height={300}>
              <LineChart data={mockData.nav}>
                <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
                <XAxis dataKey="time" stroke="#666" />
                <YAxis domain={['dataMin - 0.001', 'dataMax + 0.001']} stroke="#666" />
                <Tooltip 
                  contentStyle={{
                    backgroundColor: 'white',
                    border: '1px solid #e5e7eb',
                    borderRadius: '8px'
                  }}
                />
                <Line 
                  type="monotone" 
                  dataKey="value" 
                  stroke="#3b82f6" 
                  strokeWidth={2}
                  dot={{ fill: '#3b82f6', strokeWidth: 2, r: 4 }}
                />
              </LineChart>
            </ResponsiveContainer>
          </div>

          {/* System Status */}
          <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
            <h3 className="text-lg font-semibold text-gray-900 mb-4">System Status</h3>
            <div className="space-y-4">
              <div className="flex items-center justify-between">
                <span className="text-sm text-gray-600">Proof-of-CSV™ Oracle</span>
                <div className="flex items-center">
                  <CheckCircle className="w-4 h-4 text-emerald-500 mr-2" />
                  <span className="text-sm font-medium text-emerald-600">Active</span>
                </div>
              </div>
              <div className="flex items-center justify-between">
                <span className="text-sm text-gray-600">Compliance-by-Design™</span>
                <div className="flex items-center">
                  <CheckCircle className="w-4 h-4 text-emerald-500 mr-2" />
                  <span className="text-sm font-medium text-emerald-600">Operational</span>
                </div>
              </div>
              <div className="flex items-center justify-between">
                <span className="text-sm text-gray-600">IPFS Provenance</span>
                <div className="flex items-center">
                  <CheckCircle className="w-4 h-4 text-emerald-500 mr-2" />
                  <span className="text-sm font-medium text-emerald-600">Synced</span>
                </div>
              </div>
              <div className="flex items-center justify-between">
                <span className="text-sm text-gray-600">Last Disclosure</span>
                <span className="text-sm font-medium text-gray-900">2 hours ago</span>
              </div>
              <div className="pt-4 border-t border-gray-200">
                <div className="text-sm text-gray-600 mb-2">Current Epoch</div>
                <div className="bg-gray-50 p-3 rounded-lg">
                  <code className="text-xs text-gray-800 font-mono">QmDisclosureEpoch47...abc123</code>
                  <Link className="w-4 h-4 text-blue-500 ml-2 inline cursor-pointer" />
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* Policy Management */}
        <div className="bg-white rounded-xl shadow-sm border border-gray-200 overflow-hidden">
          <div className="px-6 py-4 border-b border-gray-200 bg-gray-50">
            <div className="flex items-center justify-between">
              <div>
                <h3 className="text-lg font-semibold text-gray-900">Policy Portfolio</h3>
                <p className="text-sm text-gray-600">Real-time monitoring of CSV-backed policies with Proof-of-CSV™</p>
              </div>
              <div className="flex items-center space-x-2">
                <FileText className="w-4 h-4 text-gray-500" />
                <span className="text-sm text-gray-500">IPFS Verified</span>
              </div>
            </div>
          </div>
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead className="bg-gray-50 border-b border-gray-200">
                <tr>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Policy ID
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Carrier
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    CSV Value
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    LTV Ratio
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Last Update
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Status
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    IPFS Proof
                  </th>
                </tr>
              </thead>
              <tbody className="bg-white divide-y divide-gray-200">
                {mockData.policies.map((policy) => (
                  <tr key={policy.id} className="hover:bg-gray-50 transition-colors">
                    <td className="px-6 py-4 whitespace-nowrap">
                      <code className="text-sm font-mono text-gray-900 bg-gray-100 px-2 py-1 rounded">
                        {policy.id}
                      </code>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                      {policy.carrier}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                      ${policy.csvValue.toLocaleString()}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <div className="flex items-center">
                        <span className={`text-sm font-medium ${
                          policy.ltvRatio > 85 ? 'text-amber-600' : 'text-gray-900'
                        }`}>
                          {policy.ltvRatio}%
                        </span>
                        {policy.ltvRatio > 85 && (
                          <AlertTriangle className="w-4 h-4 text-amber-500 ml-2" />
                        )}
                      </div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                      {policy.lastUpdate.toLocaleTimeString()}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <StatusBadge status={policy.status} />
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <div className="flex items-center">
                        <code className="text-xs text-gray-600">{policy.ipfsHash}</code>
                        <Link className="w-3 h-3 text-blue-500 ml-2 cursor-pointer" />
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>

        {/* Footer */}
        <footer className="mt-12 text-center text-sm text-gray-500 space-y-2">
          <div className="border-t border-gray-200 pt-8">
            <p className="font-semibold text-gray-700">iYield™ Protocol - Patent-Pending Insurance-Backed Securities Platform</p>
            <p className="text-gray-600">Proof-of-CSV™ | Compliance-by-Design™ | ERC-RWA:CSV Standard</p>
            <p className="text-gray-500">© 2024 iYield Protocol. All rights reserved. Patent-pending technology.</p>
          </div>
        </footer>
      </main>
    </div>
  );
}