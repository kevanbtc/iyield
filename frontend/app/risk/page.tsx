'use client'

import { useState } from 'react'
import { AlertTriangle, TrendingDown, Shield, Activity, Eye, Target, BarChart3, PieChart } from 'lucide-react'

interface RiskMetrics {
  portfolioLTV: number
  concentrationRisk: number
  liquidityRisk: number
  creditRisk: number
  marketRisk: number
  overallRiskScore: number
}

interface VaultRisk {
  vaultId: string
  policyNumber: string
  carrierName: string
  csvValue: number
  debtAmount: number
  ltv: number
  creditRating: number
  riskLevel: 'low' | 'medium' | 'high' | 'critical'
  daysToLiquidation: number
}

export default function RiskPage() {
  const [activeTab, setActiveTab] = useState<'overview' | 'vaults' | 'concentrations' | 'stress'>('overview')

  const [riskMetrics] = useState<RiskMetrics>({
    portfolioLTV: 68.5,
    concentrationRisk: 23.2,
    liquidityRisk: 15.8,
    creditRisk: 8.9,
    marketRisk: 12.4,
    overallRiskScore: 72.3
  })

  const [riskVaults] = useState<VaultRisk[]>([
    {
      vaultId: 'V001',
      policyNumber: 'POL-789012',
      carrierName: 'MetLife Inc.',
      csvValue: 75000,
      debtAmount: 63750,
      ltv: 85.0,
      creditRating: 4,
      riskLevel: 'high',
      daysToLiquidation: 7
    },
    {
      vaultId: 'V002',
      policyNumber: 'POL-456789',
      carrierName: 'Prudential Financial',
      csvValue: 125000,
      debtAmount: 100000,
      ltv: 80.0,
      creditRating: 5,
      riskLevel: 'medium',
      daysToLiquidation: 15
    },
    {
      vaultId: 'V003',
      policyNumber: 'POL-123456',
      carrierName: 'Lincoln Financial',
      csvValue: 50000,
      debtAmount: 42500,
      ltv: 85.0,
      creditRating: 3,
      riskLevel: 'critical',
      daysToLiquidation: 3
    }
  ])

  const formatCurrency = (amount: number) => {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD',
      minimumFractionDigits: 0,
      maximumFractionDigits: 0,
    }).format(amount)
  }

  const getRiskColor = (level: string) => {
    switch (level) {
      case 'low':
        return 'text-green-600 bg-green-100'
      case 'medium':
        return 'text-yellow-600 bg-yellow-100'
      case 'high':
        return 'text-orange-600 bg-orange-100'
      case 'critical':
        return 'text-red-600 bg-red-100'
      default:
        return 'text-gray-600 bg-gray-100'
    }
  }

  const getRiskLevel = (score: number) => {
    if (score >= 80) return { level: 'critical', label: 'Critical', color: 'text-red-600' }
    if (score >= 60) return { level: 'high', label: 'High', color: 'text-orange-600' }
    if (score >= 40) return { level: 'medium', label: 'Medium', color: 'text-yellow-600' }
    return { level: 'low', label: 'Low', color: 'text-green-600' }
  }

  const RiskMetricCard = ({ title, value, threshold, icon: Icon, unit = '%' }) => {
    const isOverThreshold = value > threshold
    return (
      <div className="card p-6">
        <div className="flex items-center justify-between">
          <div>
            <p className="text-sm text-gray-600">{title}</p>
            <p className={`text-2xl font-bold mt-1 ${
              isOverThreshold ? 'text-red-600' : 'text-gray-900'
            }`}>
              {value}{unit}
            </p>
            <p className="text-xs text-gray-500 mt-1">
              Threshold: {threshold}{unit}
            </p>
          </div>
          <div className={`p-3 rounded-full ${
            isOverThreshold ? 'bg-red-50' : 'bg-blue-50'
          }`}>
            <Icon className={`h-6 w-6 ${
              isOverThreshold ? 'text-red-600' : 'text-blue-600'
            }`} />
          </div>
        </div>
        {isOverThreshold && (
          <div className="mt-3 flex items-center text-red-600">
            <AlertTriangle className="h-4 w-4 mr-1" />
            <span className="text-sm">Above threshold</span>
          </div>
        )}
      </div>
    )
  }

  const VaultRiskTable = () => (
    <div className="card p-6">
      <h3 className="text-lg font-semibold text-gray-900 mb-4">High-Risk Vaults</h3>
      <div className="overflow-x-auto">
        <table className="min-w-full divide-y divide-gray-200">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                Vault
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                Carrier
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                CSV Value
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                LTV
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                Risk Level
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                Days to Liquidation
              </th>
            </tr>
          </thead>
          <tbody className="bg-white divide-y divide-gray-200">
            {riskVaults.map((vault) => (
              <tr key={vault.vaultId}>
                <td className="px-6 py-4 whitespace-nowrap">
                  <div>
                    <p className="text-sm font-medium text-gray-900">{vault.vaultId}</p>
                    <p className="text-sm text-gray-600">{vault.policyNumber}</p>
                  </div>
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                  {vault.carrierName}
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                  {formatCurrency(vault.csvValue)}
                </td>
                <td className="px-6 py-4 whitespace-nowrap">
                  <div className="text-sm text-gray-900">{vault.ltv}%</div>
                  <div className="w-full bg-gray-200 rounded-full h-2 mt-1">
                    <div 
                      className={`h-2 rounded-full ${
                        vault.ltv >= 85 ? 'bg-red-500' : 
                        vault.ltv >= 75 ? 'bg-orange-500' : 'bg-green-500'
                      }`}
                      style={{ width: `${vault.ltv}%` }}
                    ></div>
                  </div>
                </td>
                <td className="px-6 py-4 whitespace-nowrap">
                  <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${getRiskColor(vault.riskLevel)}`}>
                    {vault.riskLevel.charAt(0).toUpperCase() + vault.riskLevel.slice(1)}
                  </span>
                </td>
                <td className="px-6 py-4 whitespace-nowrap">
                  <div className={`text-sm font-medium ${
                    vault.daysToLiquidation <= 7 ? 'text-red-600' : 'text-gray-900'
                  }`}>
                    {vault.daysToLiquidation} days
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  )

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Header */}
      <header className="bg-white border-b border-gray-200">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between items-center h-16">
            <div className="flex items-center">
              <Shield className="h-6 w-6 text-red-600 mr-3" />
              <h1 className="text-2xl font-bold text-gray-900">
                Risk Monitoring
              </h1>
            </div>
            <div className="flex items-center space-x-4">
              <div className="text-right">
                <p className="text-sm text-gray-600">Overall Risk Score</p>
                <p className={`text-lg font-bold ${getRiskLevel(riskMetrics.overallRiskScore).color}`}>
                  {riskMetrics.overallRiskScore}/100
                </p>
              </div>
            </div>
          </div>
        </div>
      </header>

      {/* Main Content */}
      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        
        {/* Risk Alert Banner */}
        {riskMetrics.overallRiskScore > 70 && (
          <div className="card p-4 mb-8 bg-red-50 border-red-200">
            <div className="flex items-center">
              <AlertTriangle className="h-5 w-5 text-red-600 mr-3" />
              <div>
                <h3 className="text-sm font-medium text-red-800">High Risk Alert</h3>
                <p className="text-sm text-red-700 mt-1">
                  Portfolio risk level is elevated. Review high-risk vaults and consider risk mitigation measures.
                </p>
              </div>
            </div>
          </div>
        )}

        {/* Tabs */}
        <div className="mb-8">
          <div className="border-b border-gray-200">
            <nav className="-mb-px flex space-x-8">
              {[
                { key: 'overview', label: 'Risk Overview', icon: Eye },
                { key: 'vaults', label: 'Vault Risks', icon: Shield },
                { key: 'concentrations', label: 'Concentrations', icon: PieChart },
                { key: 'stress', label: 'Stress Testing', icon: Target },
              ].map(({ key, label, icon: Icon }) => (
                <button
                  key={key}
                  onClick={() => setActiveTab(key as any)}
                  className={`flex items-center py-2 px-1 border-b-2 font-medium text-sm ${
                    activeTab === key
                      ? 'border-red-500 text-red-600'
                      : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
                  }`}
                >
                  <Icon className="h-4 w-4 mr-2" />
                  {label}
                </button>
              ))}
            </nav>
          </div>
        </div>

        {/* Tab Content */}
        {activeTab === 'overview' && (
          <div className="space-y-8">
            {/* Risk Metrics Grid */}
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
              <RiskMetricCard
                title="Portfolio LTV"
                value={riskMetrics.portfolioLTV}
                threshold={75}
                icon={TrendingDown}
              />
              <RiskMetricCard
                title="Concentration Risk"
                value={riskMetrics.concentrationRisk}
                threshold={25}
                icon={PieChart}
              />
              <RiskMetricCard
                title="Liquidity Risk"
                value={riskMetrics.liquidityRisk}
                threshold={20}
                icon={Activity}
              />
              <RiskMetricCard
                title="Credit Risk"
                value={riskMetrics.creditRisk}
                threshold={15}
                icon={BarChart3}
              />
              <RiskMetricCard
                title="Market Risk"
                value={riskMetrics.marketRisk}
                threshold={18}
                icon={Target}
              />
              <div className="card p-6">
                <div className="flex items-center justify-between">
                  <div>
                    <p className="text-sm text-gray-600">Overall Risk Score</p>
                    <p className={`text-2xl font-bold mt-1 ${getRiskLevel(riskMetrics.overallRiskScore).color}`}>
                      {riskMetrics.overallRiskScore}/100
                    </p>
                    <p className="text-xs text-gray-500 mt-1">
                      {getRiskLevel(riskMetrics.overallRiskScore).label} Risk
                    </p>
                  </div>
                  <div className="p-3 rounded-full bg-red-50">
                    <AlertTriangle className="h-6 w-6 text-red-600" />
                  </div>
                </div>
              </div>
            </div>

            {/* High Risk Vaults */}
            <VaultRiskTable />
          </div>
        )}

        {activeTab === 'vaults' && (
          <div className="space-y-6">
            <VaultRiskTable />
            
            <div className="card p-6">
              <h3 className="text-lg font-semibold text-gray-900 mb-4">Vault Risk Distribution</h3>
              <div className="h-64 flex items-center justify-center bg-gray-50 rounded">
                <div className="text-center">
                  <BarChart3 className="h-12 w-12 text-gray-400 mx-auto mb-2" />
                  <p className="text-gray-500">Risk distribution chart would display here</p>
                  <p className="text-sm text-gray-400 mt-1">LTV distribution across all vaults</p>
                </div>
              </div>
            </div>
          </div>
        )}

        {activeTab === 'concentrations' && (
          <div className="space-y-6">
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
              <div className="card p-6">
                <h3 className="text-lg font-semibold text-gray-900 mb-4">Carrier Concentration</h3>
                <div className="space-y-3">
                  <div className="flex items-center justify-between">
                    <span className="text-sm text-gray-600">MetLife Inc.</span>
                    <div className="flex items-center space-x-2">
                      <div className="w-24 bg-gray-200 rounded-full h-2">
                        <div className="bg-blue-500 h-2 rounded-full" style={{ width: '35%' }}></div>
                      </div>
                      <span className="text-sm font-medium">35%</span>
                    </div>
                  </div>
                  <div className="flex items-center justify-between">
                    <span className="text-sm text-gray-600">Prudential Financial</span>
                    <div className="flex items-center space-x-2">
                      <div className="w-24 bg-gray-200 rounded-full h-2">
                        <div className="bg-green-500 h-2 rounded-full" style={{ width: '28%' }}></div>
                      </div>
                      <span className="text-sm font-medium">28%</span>
                    </div>
                  </div>
                  <div className="flex items-center justify-between">
                    <span className="text-sm text-gray-600">Lincoln Financial</span>
                    <div className="flex items-center space-x-2">
                      <div className="w-24 bg-gray-200 rounded-full h-2">
                        <div className="bg-purple-500 h-2 rounded-full" style={{ width: '22%' }}></div>
                      </div>
                      <span className="text-sm font-medium">22%</span>
                    </div>
                  </div>
                  <div className="flex items-center justify-between">
                    <span className="text-sm text-gray-600">Others</span>
                    <div className="flex items-center space-x-2">
                      <div className="w-24 bg-gray-200 rounded-full h-2">
                        <div className="bg-orange-500 h-2 rounded-full" style={{ width: '15%' }}></div>
                      </div>
                      <span className="text-sm font-medium">15%</span>
                    </div>
                  </div>
                </div>
              </div>

              <div className="card p-6">
                <h3 className="text-lg font-semibold text-gray-900 mb-4">Credit Rating Distribution</h3>
                <div className="space-y-3">
                  <div className="flex items-center justify-between">
                    <span className="text-sm text-gray-600">AAA (Rating 5)</span>
                    <div className="flex items-center space-x-2">
                      <div className="w-24 bg-gray-200 rounded-full h-2">
                        <div className="bg-green-500 h-2 rounded-full" style={{ width: '45%' }}></div>
                      </div>
                      <span className="text-sm font-medium">45%</span>
                    </div>
                  </div>
                  <div className="flex items-center justify-between">
                    <span className="text-sm text-gray-600">AA (Rating 4)</span>
                    <div className="flex items-center space-x-2">
                      <div className="w-24 bg-gray-200 rounded-full h-2">
                        <div className="bg-blue-500 h-2 rounded-full" style={{ width: '30%' }}></div>
                      </div>
                      <span className="text-sm font-medium">30%</span>
                    </div>
                  </div>
                  <div className="flex items-center justify-between">
                    <span className="text-sm text-gray-600">A (Rating 3)</span>
                    <div className="flex items-center space-x-2">
                      <div className="w-24 bg-gray-200 rounded-full h-2">
                        <div className="bg-yellow-500 h-2 rounded-full" style={{ width: '20%' }}></div>
                      </div>
                      <span className="text-sm font-medium">20%</span>
                    </div>
                  </div>
                  <div className="flex items-center justify-between">
                    <span className="text-sm text-gray-600">BBB & Below</span>
                    <div className="flex items-center space-x-2">
                      <div className="w-24 bg-gray-200 rounded-full h-2">
                        <div className="bg-red-500 h-2 rounded-full" style={{ width: '5%' }}></div>
                      </div>
                      <span className="text-sm font-medium">5%</span>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        )}

        {activeTab === 'stress' && (
          <div className="space-y-6">
            <div className="card p-6">
              <h3 className="text-lg font-semibold text-gray-900 mb-4">Stress Test Scenarios</h3>
              <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
                <div className="border border-gray-200 rounded p-4">
                  <h4 className="font-semibold text-gray-900 mb-2">Mild Stress (-10% CSV)</h4>
                  <div className="space-y-2 text-sm">
                    <div className="flex justify-between">
                      <span>Vaults at risk:</span>
                      <span className="font-medium text-yellow-600">12</span>
                    </div>
                    <div className="flex justify-between">
                      <span>Potential losses:</span>
                      <span className="font-medium">$125K</span>
                    </div>
                    <div className="flex justify-between">
                      <span>Portfolio impact:</span>
                      <span className="font-medium text-yellow-600">2.3%</span>
                    </div>
                  </div>
                </div>

                <div className="border border-orange-200 rounded p-4 bg-orange-50">
                  <h4 className="font-semibold text-orange-900 mb-2">Moderate Stress (-20% CSV)</h4>
                  <div className="space-y-2 text-sm">
                    <div className="flex justify-between">
                      <span>Vaults at risk:</span>
                      <span className="font-medium text-orange-600">28</span>
                    </div>
                    <div className="flex justify-between">
                      <span>Potential losses:</span>
                      <span className="font-medium">$410K</span>
                    </div>
                    <div className="flex justify-between">
                      <span>Portfolio impact:</span>
                      <span className="font-medium text-orange-600">7.8%</span>
                    </div>
                  </div>
                </div>

                <div className="border border-red-200 rounded p-4 bg-red-50">
                  <h4 className="font-semibold text-red-900 mb-2">Severe Stress (-35% CSV)</h4>
                  <div className="space-y-2 text-sm">
                    <div className="flex justify-between">
                      <span>Vaults at risk:</span>
                      <span className="font-medium text-red-600">67</span>
                    </div>
                    <div className="flex justify-between">
                      <span>Potential losses:</span>
                      <span className="font-medium">$1.2M</span>
                    </div>
                    <div className="flex justify-between">
                      <span>Portfolio impact:</span>
                      <span className="font-medium text-red-600">18.5%</span>
                    </div>
                  </div>
                </div>
              </div>
            </div>

            <div className="card p-6">
              <h3 className="text-lg font-semibold text-gray-900 mb-4">Risk Mitigation Recommendations</h3>
              <div className="space-y-4">
                <div className="flex items-start space-x-3 p-4 bg-blue-50 rounded">
                  <Shield className="h-5 w-5 text-blue-600 mt-0.5" />
                  <div>
                    <h4 className="font-semibold text-blue-900">Diversification</h4>
                    <p className="text-sm text-blue-700 mt-1">
                      Reduce carrier concentration by limiting exposure to MetLife to below 30% of total portfolio.
                    </p>
                  </div>
                </div>

                <div className="flex items-start space-x-3 p-4 bg-green-50 rounded">
                  <Target className="h-5 w-5 text-green-600 mt-0.5" />
                  <div>
                    <h4 className="font-semibold text-green-900">LTV Management</h4>
                    <p className="text-sm text-green-700 mt-1">
                      Consider reducing maximum LTV ratio from 80% to 75% to provide additional safety margin.
                    </p>
                  </div>
                </div>

                <div className="flex items-start space-x-3 p-4 bg-yellow-50 rounded">
                  <AlertTriangle className="h-5 w-5 text-yellow-600 mt-0.5" />
                  <div>
                    <h4 className="font-semibold text-yellow-900">Monitoring Enhancement</h4>
                    <p className="text-sm text-yellow-700 mt-1">
                      Implement daily monitoring for vaults with LTV above 75% and weekly revaluation.
                    </p>
                  </div>
                </div>
              </div>
            </div>
          </div>
        )}
      </main>
    </div>
  )
}