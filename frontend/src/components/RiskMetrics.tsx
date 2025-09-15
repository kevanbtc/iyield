'use client'

import { AlertTriangle, TrendingDown, Shield, Target, Activity } from 'lucide-react'

export default function RiskMetrics() {
  // Mock data - in real implementation, this would come from risk management contracts
  const riskData = {
    overallRiskScore: 'Low',
    ltvRisk: 'Medium',
    carrierRisk: 'Low',
    liquidityRisk: 'Low',
    marketRisk: 'Medium',
    currentLTV: 80.2,
    maxLTV: 85.0,
    liquidationThreshold: 85.0,
    timeToLiquidation: null, // null means healthy
    carrierDiversification: 4,
    avgCarrierRating: 'AA+',
    liquidityBuffer: 2.1, // million USD
    correlationRisk: 0.23 // correlation coefficient
  }

  const carrierBreakdown = [
    { name: 'MetLife', rating: 'AA+', exposure: 33.2, riskWeight: 0.15 },
    { name: 'Prudential', rating: 'AA+', exposure: 28.8, riskWeight: 0.15 },
    { name: 'Northwestern Mutual', rating: 'AAA', exposure: 27.5, riskWeight: 0.10 },
    { name: 'New York Life', rating: 'AAA', exposure: 10.5, riskWeight: 0.10 }
  ]

  const riskMetrics = [
    {
      title: 'LTV Risk',
      current: riskData.currentLTV,
      threshold: riskData.liquidationThreshold,
      status: riskData.ltvRisk,
      icon: Target,
      description: 'Loan-to-value ratio monitoring'
    },
    {
      title: 'Carrier Risk',
      current: riskData.avgCarrierRating,
      threshold: 'A-',
      status: riskData.carrierRisk,
      icon: Shield,
      description: 'Insurance carrier credit quality'
    },
    {
      title: 'Liquidity Risk',
      current: `$${riskData.liquidityBuffer}M`,
      threshold: '$1M',
      status: riskData.liquidityRisk,
      icon: Activity,
      description: 'Available liquidity buffer'
    }
  ]

  const stressTestScenarios = [
    {
      name: 'Carrier Downgrade',
      description: 'Major carrier downgraded to BBB',
      impact: 'Medium',
      ltvIncrease: 2.3,
      liquidationsRequired: 0
    },
    {
      name: 'Market Stress',
      description: '20% drop in CSV valuations',
      impact: 'High',
      ltvIncrease: 16.0,
      liquidationsRequired: 89
    },
    {
      name: 'Oracle Failure',
      description: 'Primary oracle goes offline',
      impact: 'Low',
      ltvIncrease: 0.0,
      liquidationsRequired: 0
    },
    {
      name: 'Mass Redemption',
      description: '50% of tokens redeemed',
      impact: 'Medium',
      ltvIncrease: 3.7,
      liquidationsRequired: 12
    }
  ]

  const getStatusColor = (status: string) => {
    switch (status.toLowerCase()) {
      case 'low': return 'green'
      case 'medium': return 'yellow'
      case 'high': return 'red'
      default: return 'gray'
    }
  }

  const getRiskLevelBg = (level: string) => {
    switch (level.toLowerCase()) {
      case 'low': return 'bg-green-50 dark:bg-green-900/20 border-green-200 dark:border-green-800'
      case 'medium': return 'bg-yellow-50 dark:bg-yellow-900/20 border-yellow-200 dark:border-yellow-800'
      case 'high': return 'bg-red-50 dark:bg-red-900/20 border-red-200 dark:border-red-800'
      default: return 'bg-slate-50 dark:bg-slate-700/20 border-slate-200 dark:border-slate-700'
    }
  }

  const getRiskLevelText = (level: string) => {
    switch (level.toLowerCase()) {
      case 'low': return 'text-green-800 dark:text-green-300'
      case 'medium': return 'text-yellow-800 dark:text-yellow-300'
      case 'high': return 'text-red-800 dark:text-red-300'
      default: return 'text-slate-800 dark:text-slate-300'
    }
  }

  return (
    <div className="space-y-6">
      {/* Overall Risk Assessment */}
      <div className="bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 p-6">
        <div className="flex items-center justify-between mb-6">
          <h3 className="text-lg font-semibold text-slate-900 dark:text-white flex items-center space-x-2">
            <AlertTriangle className="h-5 w-5 text-orange-500" />
            <span>Risk Assessment</span>
          </h3>
          <div className="text-right">
            <div className="text-2xl font-bold text-green-600 dark:text-green-400">
              {riskData.overallRiskScore}
            </div>
            <div className="text-sm text-slate-500 dark:text-slate-400">Overall Risk</div>
          </div>
        </div>

        {/* Risk Status Grid */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-6">
          {riskMetrics.map((metric, index) => {
            const Icon = metric.icon
            const colorClass = getStatusColor(metric.status)
            
            return (
              <div key={index} className={`border rounded-lg p-4 ${getRiskLevelBg(metric.status)}`}>
                <div className="flex items-center justify-between mb-3">
                  <div className={`w-8 h-8 bg-${colorClass}-100 dark:bg-${colorClass}-900/30 rounded-lg flex items-center justify-center`}>
                    <Icon className={`h-4 w-4 text-${colorClass}-600 dark:text-${colorClass}-400`} />
                  </div>
                  <span className={`px-2 py-1 text-xs font-medium rounded-full bg-${colorClass}-100 dark:bg-${colorClass}-900/30 text-${colorClass}-800 dark:text-${colorClass}-300`}>
                    {metric.status} Risk
                  </span>
                </div>
                
                <div className="space-y-2">
                  <h4 className={`font-medium ${getRiskLevelText(metric.status)}`}>
                    {metric.title}
                  </h4>
                  <div className={`text-lg font-bold ${getRiskLevelText(metric.status)}`}>
                    {typeof metric.current === 'number' ? `${metric.current}%` : metric.current}
                  </div>
                  <p className="text-xs text-slate-600 dark:text-slate-400">
                    {metric.description}
                  </p>
                </div>
              </div>
            )
          })}
        </div>

        {/* Risk Indicators */}
        <div className="space-y-4">
          <div className="flex items-center justify-between p-3 bg-slate-50 dark:bg-slate-700/50 rounded-lg">
            <span className="text-sm text-slate-600 dark:text-slate-300">Carrier Diversification</span>
            <div className="flex items-center space-x-2">
              <span className="text-sm font-medium text-slate-900 dark:text-white">
                {riskData.carrierDiversification} carriers
              </span>
              <div className="w-2 h-2 bg-green-500 rounded-full"></div>
            </div>
          </div>
          
          <div className="flex items-center justify-between p-3 bg-slate-50 dark:bg-slate-700/50 rounded-lg">
            <span className="text-sm text-slate-600 dark:text-slate-300">Correlation Risk</span>
            <div className="flex items-center space-x-2">
              <span className="text-sm font-medium text-slate-900 dark:text-white">
                {riskData.correlationRisk.toFixed(2)}
              </span>
              <div className="w-2 h-2 bg-green-500 rounded-full"></div>
            </div>
          </div>
        </div>
      </div>

      {/* Carrier Risk Breakdown */}
      <div className="bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 p-6">
        <h4 className="text-lg font-semibold text-slate-900 dark:text-white mb-4">Carrier Risk Breakdown</h4>
        
        <div className="space-y-3">
          {carrierBreakdown.map((carrier, index) => (
            <div key={index} className="flex items-center justify-between p-4 bg-slate-50 dark:bg-slate-700/50 rounded-lg">
              <div className="flex items-center space-x-4">
                <div className="w-3 h-3 bg-green-500 rounded-full"></div>
                <div>
                  <p className="font-medium text-slate-900 dark:text-white">{carrier.name}</p>
                  <p className="text-sm text-slate-500 dark:text-slate-400">Rating: {carrier.rating}</p>
                </div>
              </div>
              
              <div className="flex items-center space-x-6">
                <div className="text-right">
                  <p className="text-sm font-medium text-slate-900 dark:text-white">
                    {carrier.exposure.toFixed(1)}%
                  </p>
                  <p className="text-xs text-slate-500 dark:text-slate-400">Exposure</p>
                </div>
                
                <div className="text-right">
                  <p className="text-sm font-medium text-slate-900 dark:text-white">
                    {(carrier.riskWeight * 100).toFixed(1)}%
                  </p>
                  <p className="text-xs text-slate-500 dark:text-slate-400">Risk Weight</p>
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* Stress Test Scenarios */}
      <div className="bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 p-6">
        <h4 className="text-lg font-semibold text-slate-900 dark:text-white mb-4">Stress Test Scenarios</h4>
        
        <div className="space-y-4">
          {stressTestScenarios.map((scenario, index) => (
            <div key={index} className="border border-slate-200 dark:border-slate-700 rounded-lg p-4">
              <div className="flex items-start justify-between mb-3">
                <div>
                  <h5 className="font-medium text-slate-900 dark:text-white">{scenario.name}</h5>
                  <p className="text-sm text-slate-600 dark:text-slate-400 mt-1">
                    {scenario.description}
                  </p>
                </div>
                <span className={`px-2 py-1 text-xs font-medium rounded-full ${
                  scenario.impact === 'Low' ? 'bg-green-100 text-green-800 dark:bg-green-900/30 dark:text-green-300' :
                  scenario.impact === 'Medium' ? 'bg-yellow-100 text-yellow-800 dark:bg-yellow-900/30 dark:text-yellow-300' :
                  'bg-red-100 text-red-800 dark:bg-red-900/30 dark:text-red-300'
                }`}>
                  {scenario.impact} Impact
                </span>
              </div>
              
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div className="flex items-center justify-between p-2 bg-slate-50 dark:bg-slate-700/30 rounded">
                  <span className="text-sm text-slate-600 dark:text-slate-400">LTV Increase</span>
                  <span className="text-sm font-medium text-slate-900 dark:text-white">
                    +{scenario.ltvIncrease.toFixed(1)}%
                  </span>
                </div>
                
                <div className="flex items-center justify-between p-2 bg-slate-50 dark:bg-slate-700/30 rounded">
                  <span className="text-sm text-slate-600 dark:text-slate-400">Liquidations</span>
                  <span className={`text-sm font-medium ${
                    scenario.liquidationsRequired === 0 ? 'text-green-600 dark:text-green-400' : 'text-red-600 dark:text-red-400'
                  }`}>
                    {scenario.liquidationsRequired}
                  </span>
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* Risk Management Actions */}
      <div className="bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 p-6">
        <h4 className="text-lg font-semibold text-slate-900 dark:text-white mb-4">Automated Risk Controls</h4>
        
        <div className="space-y-4">
          <div className="flex items-center justify-between p-4 bg-green-50 dark:bg-green-900/20 border border-green-200 dark:border-green-800 rounded-lg">
            <div className="flex items-center space-x-3">
              <Shield className="h-5 w-5 text-green-600 dark:text-green-400" />
              <div>
                <p className="font-medium text-green-900 dark:text-green-100">LTV Ratchets</p>
                <p className="text-sm text-green-700 dark:text-green-300">Automatically adjust when carriers downgraded</p>
              </div>
            </div>
            <div className="text-green-700 dark:text-green-300 font-medium">Active</div>
          </div>
          
          <div className="flex items-center justify-between p-4 bg-blue-50 dark:bg-blue-900/20 border border-blue-200 dark:border-blue-800 rounded-lg">
            <div className="flex items-center space-x-3">
              <Activity className="h-5 w-5 text-blue-600 dark:text-blue-400" />
              <div>
                <p className="font-medium text-blue-900 dark:text-blue-100">Oracle Redundancy</p>
                <p className="text-sm text-blue-700 dark:text-blue-300">Multi-attestor consensus required</p>
              </div>
            </div>
            <div className="text-blue-700 dark:text-blue-300 font-medium">Active</div>
          </div>
          
          <div className="flex items-center justify-between p-4 bg-purple-50 dark:bg-purple-900/20 border border-purple-200 dark:border-purple-800 rounded-lg">
            <div className="flex items-center space-x-3">
              <AlertTriangle className="h-5 w-5 text-purple-600 dark:text-purple-400" />
              <div>
                <p className="font-medium text-purple-900 dark:text-purple-100">Emergency Pause</p>
                <p className="text-sm text-purple-700 dark:text-purple-300">Can halt operations if risk exceeds threshold</p>
              </div>
            </div>
            <div className="text-purple-700 dark:text-purple-300 font-medium">Standby</div>
          </div>
        </div>
      </div>
    </div>
  )
}