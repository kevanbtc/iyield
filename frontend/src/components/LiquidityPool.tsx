'use client'

import { Droplets, TrendingUp, Users, Percent } from 'lucide-react'

export default function LiquidityPool() {
  // Mock data - in real implementation, this would come from smart contracts
  const poolData = {
    totalAssets: 24687432,
    seniorAssets: 17281202, // 70%
    juniorAssets: 7406230,  // 30%
    seniorAPY: 4.2,
    juniorAPY: 12.8,
    totalYieldGenerated: 892456,
    seniorUsers: 847,
    juniorUsers: 289
  }

  const trancheData = [
    {
      name: 'Senior Tranche',
      type: 'senior',
      assets: poolData.seniorAssets,
      percentage: 70,
      apy: poolData.seniorAPY,
      users: poolData.seniorUsers,
      minYield: 3.0,
      maxYield: 8.0,
      riskLevel: 'Low',
      color: 'blue'
    },
    {
      name: 'Junior Tranche',
      type: 'junior', 
      assets: poolData.juniorAssets,
      percentage: 30,
      apy: poolData.juniorAPY,
      users: poolData.juniorUsers,
      minYield: 0,
      maxYield: 20.0,
      riskLevel: 'High',
      color: 'purple'
    }
  ]

  const yieldDistribution = [
    { date: '2024-09-08', seniorYield: 34521, juniorYield: 12876 },
    { date: '2024-09-09', seniorYield: 36789, juniorYield: 15432 },
    { date: '2024-09-10', seniorYield: 33456, juniorYield: 11234 },
    { date: '2024-09-11', seniorYield: 38901, juniorYield: 18765 },
    { date: '2024-09-12', seniorYield: 35678, juniorYield: 13456 },
    { date: '2024-09-13', seniorYield: 37234, juniorYield: 16789 },
    { date: '2024-09-14', seniorYield: 39876, juniorYield: 19234 }
  ]

  const formatCurrency = (amount: number) => {
    return new Intl.NumberFormat('en-US', { 
      style: 'currency', 
      currency: 'USD',
      minimumFractionDigits: 0,
      maximumFractionDigits: 0
    }).format(amount)
  }

  const formatNumber = (amount: number) => {
    return new Intl.NumberFormat('en-US').format(amount)
  }

  return (
    <div className="space-y-6">
      {/* Pool Overview */}
      <div className="bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 p-6">
        <div className="flex items-center justify-between mb-6">
          <h3 className="text-lg font-semibold text-slate-900 dark:text-white flex items-center space-x-2">
            <Droplets className="h-5 w-5 text-blue-500" />
            <span>Senior/Junior Liquidity Pool</span>
          </h3>
          <div className="text-right">
            <div className="text-2xl font-bold text-slate-900 dark:text-white">{formatCurrency(poolData.totalAssets)}</div>
            <div className="text-sm text-slate-500 dark:text-slate-400">Total Assets</div>
          </div>
        </div>

        {/* Pool Allocation Visualization */}
        <div className="mb-6">
          <div className="flex items-center justify-between mb-2">
            <span className="text-sm font-medium text-slate-700 dark:text-slate-300">Pool Allocation</span>
            <span className="text-sm text-slate-500 dark:text-slate-400">Senior/Junior Split</span>
          </div>
          <div className="w-full bg-slate-200 dark:bg-slate-600 rounded-full h-4 flex overflow-hidden">
            <div className="bg-gradient-to-r from-blue-400 to-blue-500 flex-1" style={{ flexBasis: '70%' }}>
              <div className="h-full flex items-center justify-center">
                <span className="text-xs font-medium text-white">Senior 70%</span>
              </div>
            </div>
            <div className="bg-gradient-to-r from-purple-400 to-purple-500 flex-1" style={{ flexBasis: '30%' }}>
              <div className="h-full flex items-center justify-center">
                <span className="text-xs font-medium text-white">Junior 30%</span>
              </div>
            </div>
          </div>
        </div>

        {/* Key Metrics */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          <div className="bg-gradient-to-br from-green-50 to-green-100 dark:from-green-900/20 dark:to-green-800/20 border border-green-200 dark:border-green-700 rounded-lg p-4">
            <div className="flex items-center justify-between mb-2">
              <span className="text-sm font-medium text-green-700 dark:text-green-300">Total Yield</span>
              <TrendingUp className="h-4 w-4 text-green-600 dark:text-green-400" />
            </div>
            <div className="text-xl font-bold text-green-900 dark:text-green-100">
              {formatCurrency(poolData.totalYieldGenerated)}
            </div>
            <div className="text-xs text-green-600 dark:text-green-400 mt-1">
              Generated this month
            </div>
          </div>

          <div className="bg-gradient-to-br from-blue-50 to-blue-100 dark:from-blue-900/20 dark:to-blue-800/20 border border-blue-200 dark:border-blue-700 rounded-lg p-4">
            <div className="flex items-center justify-between mb-2">
              <span className="text-sm font-medium text-blue-700 dark:text-blue-300">Senior APY</span>
              <Percent className="h-4 w-4 text-blue-600 dark:text-blue-400" />
            </div>
            <div className="text-xl font-bold text-blue-900 dark:text-blue-100">
              {poolData.seniorAPY.toFixed(1)}%
            </div>
            <div className="text-xs text-blue-600 dark:text-blue-400 mt-1">
              Low risk, guaranteed
            </div>
          </div>

          <div className="bg-gradient-to-br from-purple-50 to-purple-100 dark:from-purple-900/20 dark:to-purple-800/20 border border-purple-200 dark:border-purple-700 rounded-lg p-4">
            <div className="flex items-center justify-between mb-2">
              <span className="text-sm font-medium text-purple-700 dark:text-purple-300">Junior APY</span>
              <TrendingUp className="h-4 w-4 text-purple-600 dark:text-purple-400" />
            </div>
            <div className="text-xl font-bold text-purple-900 dark:text-purple-100">
              {poolData.juniorAPY.toFixed(1)}%
            </div>
            <div className="text-xs text-purple-600 dark:text-purple-400 mt-1">
              High risk, variable
            </div>
          </div>
        </div>
      </div>

      {/* Tranche Details */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {trancheData.map((tranche) => (
          <div key={tranche.type} className="bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 p-6">
            <div className="flex items-center justify-between mb-4">
              <h4 className="text-lg font-semibold text-slate-900 dark:text-white">{tranche.name}</h4>
              <span className={`px-2 py-1 text-xs font-medium rounded-full ${
                tranche.riskLevel === 'Low' 
                  ? 'bg-green-100 text-green-800 dark:bg-green-900/30 dark:text-green-300'
                  : 'bg-orange-100 text-orange-800 dark:bg-orange-900/30 dark:text-orange-300'
              }`}>
                {tranche.riskLevel} Risk
              </span>
            </div>

            <div className="space-y-4">
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="text-sm font-medium text-slate-500 dark:text-slate-400">Assets</label>
                  <p className="text-lg font-semibold text-slate-900 dark:text-white">
                    {formatCurrency(tranche.assets)}
                  </p>
                </div>
                <div>
                  <label className="text-sm font-medium text-slate-500 dark:text-slate-400">Current APY</label>
                  <p className="text-lg font-semibold text-slate-900 dark:text-white">
                    {tranche.apy.toFixed(1)}%
                  </p>
                </div>
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="text-sm font-medium text-slate-500 dark:text-slate-400">Investors</label>
                  <p className="text-lg font-semibold text-slate-900 dark:text-white">
                    {formatNumber(tranche.users)}
                  </p>
                </div>
                <div>
                  <label className="text-sm font-medium text-slate-500 dark:text-slate-400">Pool Share</label>
                  <p className="text-lg font-semibold text-slate-900 dark:text-white">
                    {tranche.percentage}%
                  </p>
                </div>
              </div>

              <div className="border-t border-slate-200 dark:border-slate-700 pt-4">
                <div className="flex items-center justify-between text-sm">
                  <span className="text-slate-500 dark:text-slate-400">Yield Range:</span>
                  <span className="font-medium text-slate-900 dark:text-white">
                    {tranche.minYield}% - {tranche.maxYield}%
                  </span>
                </div>
              </div>

              <button className={`w-full py-2 px-4 rounded-lg font-medium transition-colors duration-200 ${
                tranche.color === 'blue' 
                  ? 'bg-blue-500 hover:bg-blue-600 text-white'
                  : 'bg-purple-500 hover:bg-purple-600 text-white'
              }`}>
                Invest in {tranche.name}
              </button>
            </div>
          </div>
        ))}
      </div>

      {/* Waterfall Distribution Model */}
      <div className="bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 p-6">
        <h4 className="text-lg font-semibold text-slate-900 dark:text-white mb-4">Waterfall Distribution Model</h4>
        
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
          <div className="space-y-3">
            <div className="w-full bg-blue-100 dark:bg-blue-900/30 border-2 border-blue-300 dark:border-blue-700 rounded-lg p-4">
              <div className="text-center">
                <div className="text-2xl mb-2">💧</div>
                <div className="font-semibold text-blue-900 dark:text-blue-100">Yield Input</div>
                <div className="text-sm text-blue-700 dark:text-blue-300 mt-1">
                  From CSV interest and redemptions
                </div>
              </div>
            </div>
          </div>

          <div className="space-y-3">
            <div className="w-full bg-green-100 dark:bg-green-900/30 border-2 border-green-300 dark:border-green-700 rounded-lg p-4">
              <div className="text-center">
                <div className="text-2xl mb-2">🛡️</div>
                <div className="font-semibold text-green-900 dark:text-green-100">Senior First</div>
                <div className="text-sm text-green-700 dark:text-green-300 mt-1">
                  Guaranteed {poolData.seniorAPY}% minimum yield
                </div>
              </div>
            </div>
            <div className="text-center">
              <div className="text-xs text-slate-500 dark:text-slate-400">Then...</div>
            </div>
          </div>

          <div className="space-y-3">
            <div className="w-full bg-purple-100 dark:bg-purple-900/30 border-2 border-purple-300 dark:border-purple-700 rounded-lg p-4">
              <div className="text-center">
                <div className="text-2xl mb-2">🚀</div>
                <div className="font-semibold text-purple-900 dark:text-purple-100">Junior Remainder</div>
                <div className="text-sm text-purple-700 dark:text-purple-300 mt-1">
                  Gets remaining yield (up to {poolData.juniorAPY}%)
                </div>
              </div>
            </div>
          </div>
        </div>

        <div className="mt-6 p-4 bg-slate-50 dark:bg-slate-700/50 rounded-lg">
          <h5 className="font-medium text-slate-900 dark:text-white mb-2">How it works:</h5>
          <ol className="text-sm text-slate-600 dark:text-slate-300 space-y-1 list-decimal list-inside">
            <li>Senior tranche receives minimum guaranteed yield first</li>
            <li>Remaining yield flows to junior tranche for higher potential returns</li>
            <li>Senior tranche protected by 80% senior protection ratio</li>
            <li>Junior takes first loss but gets unlimited upside</li>
          </ol>
        </div>
      </div>

      {/* Recent Yield Distribution */}
      <div className="bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 p-6">
        <h4 className="text-lg font-semibold text-slate-900 dark:text-white mb-4">Recent Yield Distribution</h4>
        
        <div className="space-y-3">
          {yieldDistribution.slice(-5).reverse().map((distribution, index) => (
            <div key={distribution.date} className="flex items-center justify-between p-3 bg-slate-50 dark:bg-slate-700/50 rounded-lg">
              <div>
                <p className="font-medium text-slate-900 dark:text-white">
                  {new Date(distribution.date).toLocaleDateString()}
                </p>
                <p className="text-sm text-slate-500 dark:text-slate-400">
                  Total: {formatCurrency(distribution.seniorYield + distribution.juniorYield)}
                </p>
              </div>
              <div className="flex items-center space-x-4">
                <div className="text-right">
                  <p className="text-sm font-medium text-blue-600 dark:text-blue-400">
                    {formatCurrency(distribution.seniorYield)}
                  </p>
                  <p className="text-xs text-slate-500 dark:text-slate-400">Senior</p>
                </div>
                <div className="text-right">
                  <p className="text-sm font-medium text-purple-600 dark:text-purple-400">
                    {formatCurrency(distribution.juniorYield)}
                  </p>
                  <p className="text-xs text-slate-500 dark:text-slate-400">Junior</p>
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  )
}