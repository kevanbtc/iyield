'use client'

import { TrendingUp, Shield, Clock, DollarSign } from 'lucide-react'

export default function StatsOverview() {
  // Mock data - in real implementation, this would come from blockchain
  const stats = [
    {
      label: 'Total CSV Value',
      value: '$24.7M',
      change: '+12.3%',
      changeType: 'positive',
      icon: DollarSign,
      description: 'Total cash surrender value collateral'
    },
    {
      label: 'Tokens Outstanding',
      value: '19.8M',
      change: '+8.7%',
      changeType: 'positive', 
      icon: TrendingUp,
      description: 'iYield tokens in circulation'
    },
    {
      label: 'Current LTV',
      value: '80.2%',
      change: '-2.1%',
      changeType: 'positive',
      icon: Shield,
      description: 'Loan-to-value ratio (healthy below 85%)'
    },
    {
      label: 'Oracle Freshness',
      value: '2 mins',
      change: 'Live',
      changeType: 'neutral',
      icon: Clock,
      description: 'Last Proof-of-CSV™ attestation'
    }
  ]

  return (
    <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
      {stats.map((stat) => {
        const Icon = stat.icon
        return (
          <div
            key={stat.label}
            className="bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 p-6 hover:shadow-lg transition-shadow duration-200"
          >
            <div className="flex items-start justify-between">
              <div className="flex-1">
                <p className="text-sm font-medium text-slate-500 dark:text-slate-400 mb-2">
                  {stat.label}
                </p>
                <p className="text-2xl font-bold text-slate-900 dark:text-white mb-1">
                  {stat.value}
                </p>
                <div className="flex items-center space-x-1">
                  <span className={`text-sm font-medium ${
                    stat.changeType === 'positive' ? 'text-green-600 dark:text-green-400' :
                    stat.changeType === 'negative' ? 'text-red-600 dark:text-red-400' :
                    'text-slate-500 dark:text-slate-400'
                  }`}>
                    {stat.change}
                  </span>
                  {stat.changeType !== 'neutral' && (
                    <span className="text-xs text-slate-400">vs last 24h</span>
                  )}
                </div>
              </div>
              <div className="flex-shrink-0">
                <div className="w-12 h-12 bg-gradient-to-br from-blue-50 to-purple-50 dark:from-blue-900/20 dark:to-purple-900/20 rounded-lg flex items-center justify-center">
                  <Icon className="h-6 w-6 text-blue-600 dark:text-blue-400" />
                </div>
              </div>
            </div>
            <p className="text-xs text-slate-500 dark:text-slate-400 mt-3 pt-3 border-t border-slate-100 dark:border-slate-700">
              {stat.description}
            </p>
          </div>
        )
      })}
    </div>
  )
}