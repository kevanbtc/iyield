'use client'

import { Vault, TrendingUp, AlertTriangle, ArrowUpRight, ArrowDownRight } from 'lucide-react'

interface VaultMetricsProps {
  detailed?: boolean
}

export default function VaultMetrics({ detailed = false }: VaultMetricsProps) {
  // Mock data - in real implementation, this would come from smart contracts
  const vaultData = {
    totalCollateral: 24687432,
    totalIssued: 19823156,
    totalRedeemed: 2456789,
    currentLTV: 80.2,
    maxLTV: 85.0,
    liquidationThreshold: 85.0,
    activePositions: 1247,
    pendingRedemptions: 23,
    totalLiquidations: 0
  }

  const recentTransactions = [
    { type: 'DEPOSIT', amount: 125000, user: '0x1234...5678', ltv: 78.5, time: '5m ago' },
    { type: 'REDEMPTION', amount: 85000, user: '0x9876...5432', ltv: 82.1, time: '12m ago' },
    { type: 'DEPOSIT', amount: 200000, user: '0xabcd...efgh', ltv: 75.3, time: '23m ago' },
    { type: 'REDEMPTION', amount: 50000, user: '0x5555...7777', ltv: 79.8, time: '31m ago' }
  ]

  const topPositions = [
    { user: '0x1111...2222', collateral: 2150000, tokens: 1720000, ltv: 80.0, health: 'good' },
    { user: '0x3333...4444', collateral: 1875000, tokens: 1500000, ltv: 80.0, health: 'good' },
    { user: '0x5555...6666', collateral: 1625000, tokens: 1365000, ltv: 84.0, health: 'warning' },
    { user: '0x7777...8888', collateral: 1450000, tokens: 1218000, ltv: 84.0, health: 'warning' },
    { user: '0x9999...aaaa', collateral: 1275000, tokens: 1020000, ltv: 80.0, health: 'good' }
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
    <div className="bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 p-6">
      <div className="flex items-center justify-between mb-6">
        <h3 className="text-lg font-semibold text-slate-900 dark:text-white flex items-center space-x-2">
          <Vault className="h-5 w-5 text-blue-500" />
          <span>CSV Vault Metrics</span>
        </h3>
        <div className="flex items-center space-x-4">
          <div className="text-right">
            <div className="text-lg font-bold text-slate-900 dark:text-white">{vaultData.currentLTV.toFixed(1)}%</div>
            <div className="text-sm text-slate-500 dark:text-slate-400">Current LTV</div>
          </div>
          <div className={`w-3 h-3 rounded-full ${
            vaultData.currentLTV <= 80 ? 'bg-green-500' : 
            vaultData.currentLTV <= 85 ? 'bg-yellow-500' : 'bg-red-500'
          }`}></div>
        </div>
      </div>

      {/* Key Metrics */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-6">
        <div className="bg-gradient-to-br from-blue-50 to-blue-100 dark:from-blue-900/20 dark:to-blue-800/20 border border-blue-200 dark:border-blue-700 rounded-lg p-4">
          <div className="flex items-center justify-between mb-2">
            <span className="text-sm font-medium text-blue-700 dark:text-blue-300">Total Collateral</span>
            <TrendingUp className="h-4 w-4 text-blue-600 dark:text-blue-400" />
          </div>
          <div className="text-xl font-bold text-blue-900 dark:text-blue-100">
            {formatCurrency(vaultData.totalCollateral)}
          </div>
          <div className="text-xs text-blue-600 dark:text-blue-400 mt-1">
            CSV locked in vault
          </div>
        </div>

        <div className="bg-gradient-to-br from-green-50 to-green-100 dark:from-green-900/20 dark:to-green-800/20 border border-green-200 dark:border-green-700 rounded-lg p-4">
          <div className="flex items-center justify-between mb-2">
            <span className="text-sm font-medium text-green-700 dark:text-green-300">Tokens Issued</span>
            <ArrowUpRight className="h-4 w-4 text-green-600 dark:text-green-400" />
          </div>
          <div className="text-xl font-bold text-green-900 dark:text-green-100">
            {formatNumber(vaultData.totalIssued)}
          </div>
          <div className="text-xs text-green-600 dark:text-green-400 mt-1">
            iYield tokens outstanding
          </div>
        </div>

        <div className="bg-gradient-to-br from-purple-50 to-purple-100 dark:from-purple-900/20 dark:to-purple-800/20 border border-purple-200 dark:border-purple-700 rounded-lg p-4">
          <div className="flex items-center justify-between mb-2">
            <span className="text-sm font-medium text-purple-700 dark:text-purple-300">Active Positions</span>
            <Vault className="h-4 w-4 text-purple-600 dark:text-purple-400" />
          </div>
          <div className="text-xl font-bold text-purple-900 dark:text-purple-100">
            {formatNumber(vaultData.activePositions)}
          </div>
          <div className="text-xs text-purple-600 dark:text-purple-400 mt-1">
            Users with collateral
          </div>
        </div>
      </div>

      {/* LTV Health Indicator */}
      <div className="mb-6">
        <div className="flex items-center justify-between mb-2">
          <span className="text-sm font-medium text-slate-700 dark:text-slate-300">LTV Health</span>
          <span className="text-sm text-slate-500 dark:text-slate-400">
            {vaultData.currentLTV.toFixed(1)}% / {vaultData.maxLTV}% max
          </span>
        </div>
        <div className="w-full bg-slate-200 dark:bg-slate-600 rounded-full h-3 relative">
          <div 
            className={`h-3 rounded-full transition-all duration-300 ${
              vaultData.currentLTV <= 75 ? 'bg-gradient-to-r from-green-400 to-green-500' :
              vaultData.currentLTV <= 80 ? 'bg-gradient-to-r from-yellow-400 to-yellow-500' :
              vaultData.currentLTV <= 85 ? 'bg-gradient-to-r from-orange-400 to-orange-500' :
              'bg-gradient-to-r from-red-400 to-red-500'
            }`}
            style={{ width: `${Math.min((vaultData.currentLTV / vaultData.maxLTV) * 100, 100)}%` }}
          ></div>
          {/* Liquidation threshold marker */}
          <div 
            className="absolute top-0 w-0.5 h-3 bg-red-500"
            style={{ left: `${(vaultData.liquidationThreshold / vaultData.maxLTV) * 100}%` }}
          ></div>
        </div>
        <div className="flex justify-between text-xs text-slate-500 dark:text-slate-400 mt-1">
          <span>0%</span>
          <span>Liquidation: {vaultData.liquidationThreshold}%</span>
          <span>{vaultData.maxLTV}%</span>
        </div>
      </div>

      {detailed ? (
        <>
          {/* Top Positions */}
          <div className="mb-6">
            <h4 className="font-medium text-slate-900 dark:text-white mb-3">Largest Positions</h4>
            <div className="space-y-2">
              {topPositions.map((position, index) => (
                <div key={index} className="flex items-center justify-between p-3 bg-slate-50 dark:bg-slate-700/50 rounded-lg">
                  <div className="flex items-center space-x-3">
                    <div className={`w-2 h-2 rounded-full ${
                      position.health === 'good' ? 'bg-green-500' :
                      position.health === 'warning' ? 'bg-yellow-500' :
                      'bg-red-500'
                    }`}></div>
                    <div>
                      <p className="font-mono text-sm text-slate-900 dark:text-white">{position.user}</p>
                      <p className="text-xs text-slate-500 dark:text-slate-400">
                        Collateral: {formatCurrency(position.collateral)}
                      </p>
                    </div>
                  </div>
                  <div className="text-right">
                    <p className="text-sm font-medium text-slate-900 dark:text-white">
                      {formatNumber(position.tokens)} tokens
                    </p>
                    <p className={`text-xs ${
                      position.ltv <= 80 ? 'text-green-600 dark:text-green-400' :
                      position.ltv <= 85 ? 'text-yellow-600 dark:text-yellow-400' :
                      'text-red-600 dark:text-red-400'
                    }`}>
                      {position.ltv}% LTV
                    </p>
                  </div>
                </div>
              ))}
            </div>
          </div>

          {/* Recent Transactions */}
          <div>
            <h4 className="font-medium text-slate-900 dark:text-white mb-3">Recent Transactions</h4>
            <div className="space-y-2">
              {recentTransactions.map((tx, index) => {
                const isDeposit = tx.type === 'DEPOSIT'
                const Icon = isDeposit ? ArrowUpRight : ArrowDownRight
                
                return (
                  <div key={index} className="flex items-center justify-between p-3 bg-slate-50 dark:bg-slate-700/50 rounded-lg">
                    <div className="flex items-center space-x-3">
                      <div className={`w-8 h-8 ${
                        isDeposit ? 'bg-green-100 dark:bg-green-900/30' : 'bg-blue-100 dark:bg-blue-900/30'
                      } rounded-lg flex items-center justify-center`}>
                        <Icon className={`h-4 w-4 ${
                          isDeposit ? 'text-green-600 dark:text-green-400' : 'text-blue-600 dark:text-blue-400'
                        }`} />
                      </div>
                      <div>
                        <p className="text-sm font-medium text-slate-900 dark:text-white">
                          {isDeposit ? 'Deposit' : 'Redemption'}
                        </p>
                        <p className="text-xs text-slate-500 dark:text-slate-400">
                          {tx.user} • LTV: {tx.ltv}%
                        </p>
                      </div>
                    </div>
                    <div className="text-right">
                      <p className="text-sm font-medium text-slate-900 dark:text-white">
                        {formatCurrency(tx.amount)}
                      </p>
                      <p className="text-xs text-slate-500 dark:text-slate-400">
                        {tx.time}
                      </p>
                    </div>
                  </div>
                )
              })}
            </div>
          </div>
        </>
      ) : (
        /* Summary View */
        <div className="space-y-3">
          <div className="flex items-center justify-between p-3 bg-slate-50 dark:bg-slate-700/50 rounded-lg">
            <span className="text-sm text-slate-600 dark:text-slate-300">Collateralization Ratio</span>
            <span className="text-sm font-medium text-slate-900 dark:text-white">
              {(100 / vaultData.currentLTV * 100).toFixed(0)}%
            </span>
          </div>
          
          <div className="flex items-center justify-between p-3 bg-slate-50 dark:bg-slate-700/50 rounded-lg">
            <span className="text-sm text-slate-600 dark:text-slate-300">Pending Redemptions</span>
            <span className="text-sm font-medium text-slate-900 dark:text-white">
              {vaultData.pendingRedemptions}
            </span>
          </div>
          
          <div className="flex items-center justify-between p-3 bg-slate-50 dark:bg-slate-700/50 rounded-lg">
            <span className="text-sm text-slate-600 dark:text-slate-300">Liquidations (24h)</span>
            <span className="text-sm font-medium text-green-600 dark:text-green-400">
              {vaultData.totalLiquidations}
            </span>
          </div>
        </div>
      )}
    </div>
  )
}