import React, { useState, useEffect } from 'react';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from 'recharts';
import { Shield, Activity, TrendingUp, Users, AlertTriangle, CheckCircle } from 'lucide-react';

// Mock data for demonstration
const mockData = {
  nav: [
    { time: '00:00', value: 1.00 },
    { time: '06:00', value: 1.002 },
    { time: '12:00', value: 1.005 },
    { time: '18:00', value: 1.008 },
    { time: '24:00', value: 1.012 },
  ],
  policies: [
    { id: 'POLICY_001', carrier: 'MetLife', csvValue: 100000, ltvRatio: 80, lastUpdate: new Date(), status: 'active' },
    { id: 'POLICY_002', carrier: 'Prudential', csvValue: 250000, ltvRatio: 75, lastUpdate: new Date(), status: 'active' },
    { id: 'POLICY_003', carrier: 'Northwestern Mutual', csvValue: 180000, ltvRatio: 85, lastUpdate: new Date(), status: 'warning' },
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
    positive: 'text-success-600',
    negative: 'text-danger-600',
    neutral: 'text-gray-600'
  }[changeType];

  return (
    <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
      <div className="flex items-center justify-between">
        <div>
          <p className="text-sm text-gray-600 mb-1">{title}</p>
          <p className="text-3xl font-bold text-gray-900">{value}</p>
          <p className={`text-sm ${changeColor} font-medium`}>{change}</p>
        </div>
        <div className="w-12 h-12 bg-primary-50 rounded-lg flex items-center justify-center">
          {icon}
        </div>
      </div>
    </div>
  );
};

const StatusBadge: React.FC<{ status: string }> = ({ status }) => {
  const colors = {
    active: 'bg-success-100 text-success-800',
    warning: 'bg-warning-100 text-warning-800',
    critical: 'bg-danger-100 text-danger-800'
  };

  return (
    <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${colors[status as keyof typeof colors] || colors.active}`}>
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
      <header className="bg-white border-b border-gray-200">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between items-center h-16">
            <div className="flex items-center">
              <h1 className="text-2xl font-bold text-gray-900">iYield™ Protocol</h1>
              <span className="ml-3 text-sm text-gray-500 bg-gray-100 px-2 py-1 rounded">
                Insurance-Backed Yield Notes
              </span>
            </div>
            <div className="flex items-center space-x-4">
              <div className="text-sm text-gray-600">
                Last Update: {currentTime.toLocaleTimeString()}
              </div>
              <div className="flex items-center">
                <div className={`w-2 h-2 rounded-full ${isConnected ? 'bg-success-500' : 'bg-danger-500'}`}></div>
                <span className="ml-2 text-sm text-gray-600">
                  {isConnected ? 'Connected' : 'Disconnected'}
                </span>
              </div>
            </div>
          </div>
        </div>
      </header>

      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {/* Key Metrics */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
          <DashboardCard
            title="Net Asset Value"
            value="$1.012"
            change="+1.2% (24h)"
            changeType="positive"
            icon={<TrendingUp className="w-6 h-6 text-primary-600" />}
          />
          <DashboardCard
            title="Total CSV Value"
            value="$530,000"
            change="+2.3% (24h)"
            changeType="positive"
            icon={<Activity className="w-6 h-6 text-primary-600" />}
          />
          <DashboardCard
            title="Token Supply"
            value="425,000"
            change="No change"
            changeType="neutral"
            icon={<Users className="w-6 h-6 text-primary-600" />}
          />
          <DashboardCard
            title="Avg. LTV Ratio"
            value="80.2%"
            change="-0.5% (24h)"
            changeType="positive"
            icon={<Shield className="w-6 h-6 text-primary-600" />}
          />
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-2 gap-8 mb-8">
          {/* NAV Chart */}
          <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
            <h3 className="text-lg font-semibold text-gray-900 mb-4">NAV Performance (24h)</h3>
            <ResponsiveContainer width="100%" height={300}>
              <LineChart data={mockData.nav}>
                <CartesianGrid strokeDasharray="3 3" />
                <XAxis dataKey="time" />
                <YAxis domain={['dataMin - 0.001', 'dataMax + 0.001']} />
                <Tooltip />
                <Line type="monotone" dataKey="value" stroke="#3b82f6" strokeWidth={2} />
              </LineChart>
            </ResponsiveContainer>
          </div>

          {/* System Status */}
          <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
            <h3 className="text-lg font-semibold text-gray-900 mb-4">System Status</h3>
            <div className="space-y-4">
              <div className="flex items-center justify-between">
                <span className="text-sm text-gray-600">Oracle Status</span>
                <div className="flex items-center">
                  <CheckCircle className="w-4 h-4 text-success-500 mr-2" />
                  <span className="text-sm font-medium text-success-600">Active</span>
                </div>
              </div>
              <div className="flex items-center justify-between">
                <span className="text-sm text-gray-600">Compliance Engine</span>
                <div className="flex items-center">
                  <CheckCircle className="w-4 h-4 text-success-500 mr-2" />
                  <span className="text-sm font-medium text-success-600">Operational</span>
                </div>
              </div>
              <div className="flex items-center justify-between">
                <span className="text-sm text-gray-600">IPFS Provenance</span>
                <div className="flex items-center">
                  <CheckCircle className="w-4 h-4 text-success-500 mr-2" />
                  <span className="text-sm font-medium text-success-600">Synced</span>
                </div>
              </div>
              <div className="flex items-center justify-between">
                <span className="text-sm text-gray-600">Last Disclosure</span>
                <span className="text-sm font-medium text-gray-900">2 hours ago</span>
              </div>
              <div className="pt-4 border-t">
                <div className="text-sm text-gray-600 mb-2">Current Epoch</div>
                <div className="bg-gray-100 p-3 rounded-md">
                  <code className="text-xs text-gray-800">QmDisclosureEpoch47...abc123</code>
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* Policy Management */}
        <div className="bg-white rounded-lg shadow-sm border border-gray-200">
          <div className="px-6 py-4 border-b border-gray-200">
            <h3 className="text-lg font-semibold text-gray-900">Policy Portfolio</h3>
            <p className="text-sm text-gray-600">Real-time monitoring of CSV-backed policies</p>
          </div>
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead className="bg-gray-50">
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
                </tr>
              </thead>
              <tbody className="bg-white divide-y divide-gray-200">
                {mockData.policies.map((policy) => (
                  <tr key={policy.id} className="hover:bg-gray-50">
                    <td className="px-6 py-4 whitespace-nowrap">
                      <code className="text-sm font-mono text-gray-900">{policy.id}</code>
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
                          policy.ltvRatio > 85 ? 'text-warning-600' : 'text-gray-900'
                        }`}>
                          {policy.ltvRatio}%
                        </span>
                        {policy.ltvRatio > 85 && (
                          <AlertTriangle className="w-4 h-4 text-warning-500 ml-2" />
                        )}
                      </div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                      {policy.lastUpdate.toLocaleTimeString()}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <StatusBadge status={policy.status} />
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>

        {/* Footer */}
        <footer className="mt-12 text-center text-sm text-gray-500">
          <div className="space-y-2">
            <p>iYield™ Protocol - Patent-Pending Insurance-Backed Securities Platform</p>
            <p>Proof-of-CSV™ | Compliance-by-Design™ | ERC-RWA:CSV Standard</p>
            <p>© 2024 iYield Protocol. All rights reserved.</p>
          </div>
        </footer>
      </main>
    </div>
  );
}