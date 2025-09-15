'use client'

import { useState } from 'react'
import { TrendingUp, DollarSign, Percent, Clock, Info, ArrowUpDown, Plus, Minus } from 'lucide-react'

interface TrancheData {
  type: 'senior' | 'junior'
  name: string
  totalDeposits: number
  userDeposits: number
  userShares: number
  yieldRate: number
  minDeposit: number
  lockupPeriod: number
  currentYield: number
  isDeposited: boolean
}

interface PoolStats {
  totalPoolValue: number
  utilization: number
  seniorTranche: TrancheData
  juniorTranche: TrancheData
}

export default function LiquidityPage() {
  const [activeTab, setActiveTab] = useState<'overview' | 'senior' | 'junior' | 'history'>('overview')
  const [depositAmount, setDepositAmount] = useState('')
  const [withdrawAmount, setWithdrawAmount] = useState('')

  const [poolStats] = useState<PoolStats>({
    totalPoolValue: 8750000,
    utilization: 67.3,
    seniorTranche: {
      type: 'senior',
      name: 'Senior Tranche',
      totalDeposits: 6250000,
      userDeposits: 50000,
      userShares: 50000,
      yieldRate: 4.2,
      minDeposit: 1000,
      lockupPeriod: 90,
      currentYield: 2100,
      isDeposited: true
    },
    juniorTranche: {
      type: 'junior', 
      name: 'Junior Tranche',
      totalDeposits: 2500000,
      userDeposits: 25000,
      userShares: 25000,
      yieldRate: 8.7,
      minDeposit: 10000,
      lockupPeriod: 180,
      currentYield: 2175,
      isDeposited: true
    }
  })

  const formatCurrency = (amount: number) => {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD',
      minimumFractionDigits: 0,
      maximumFractionDigits: 0,
    }).format(amount)
  }

  const TrancheCard = ({ tranche }: { tranche: TrancheData }) => (
    <div className="card p-6">
      <div className="flex items-center justify-between mb-4">
        <div>
          <h3 className="text-lg font-semibold text-gray-900">{tranche.name}</h3>
          <p className={`text-sm ${
            tranche.type === 'senior' ? 'text-blue-600' : 'text-purple-600'
          }`}>
            {tranche.type === 'senior' ? 'Lower Risk • Priority Returns' : 'Higher Risk • Excess Returns'}
          </p>
        </div>
        <div className={`p-2 rounded-full ${
          tranche.type === 'senior' ? 'bg-blue-100' : 'bg-purple-100'
        }`}>
          <TrendingUp className={`h-5 w-5 ${
            tranche.type === 'senior' ? 'text-blue-600' : 'text-purple-600'
          }`} />
        </div>
      </div>

      <div className="grid grid-cols-2 gap-4 mb-4">
        <div>
          <p className="text-xs text-gray-600">Total Deposits</p>
          <p className="text-lg font-bold text-gray-900">{formatCurrency(tranche.totalDeposits)}</p>
        </div>
        <div>
          <p className="text-xs text-gray-600">Current APY</p>
          <p className="text-lg font-bold text-green-600">{tranche.yieldRate}%</p>
        </div>
      </div>

      {tranche.isDeposited && (
        <div className="bg-gray-50 rounded p-4 mb-4">
          <p className="text-sm font-medium text-gray-900 mb-2">Your Position</p>
          <div className="grid grid-cols-2 gap-4 text-sm">
            <div>
              <p className="text-gray-600">Deposited</p>
              <p className="font-semibold">{formatCurrency(tranche.userDeposits)}</p>
            </div>
            <div>
              <p className="text-gray-600">Earned</p>
              <p className="font-semibold text-green-600">{formatCurrency(tranche.currentYield)}</p>
            </div>
          </div>
        </div>
      )}

      <div className="space-y-2 text-sm text-gray-600 mb-4">
        <div className="flex justify-between">
          <span>Minimum Deposit:</span>
          <span className="font-medium">{formatCurrency(tranche.minDeposit)}</span>
        </div>
        <div className="flex justify-between">
          <span>Lockup Period:</span>
          <span className="font-medium">{tranche.lockupPeriod} days</span>
        </div>
      </div>

      <div className="flex space-x-2">
        <button className="btn btn-primary flex-1">
          <Plus className="h-4 w-4 mr-1" />
          Deposit
        </button>
        {tranche.isDeposited && (
          <button className="btn btn-secondary flex-1">
            <Minus className="h-4 w-4 mr-1" />
            Withdraw
          </button>
        )}
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
              <ArrowUpDown className="h-6 w-6 text-blue-600 mr-3" />
              <h1 className="text-2xl font-bold text-gray-900">
                Liquidity Pools
              </h1>
            </div>
            <div className="flex items-center space-x-4">
              <div className="text-right">
                <p className="text-sm text-gray-600">Pool Utilization</p>
                <p className="text-lg font-bold text-blue-600">{poolStats.utilization}%</p>
              </div>
            </div>
          </div>
        </div>
      </header>

      {/* Main Content */}
      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        
        {/* Pool Overview Stats */}
        <div className="grid grid-cols-1 md:grid-cols-4 gap-6 mb-8">
          <div className="card p-6">
            <div className="flex items-center">
              <DollarSign className="h-8 w-8 text-green-500" />
              <div className="ml-4">
                <p className="text-sm text-gray-600">Total Pool Value</p>
                <p className="text-2xl font-bold text-gray-900">
                  {formatCurrency(poolStats.totalPoolValue)}
                </p>
              </div>
            </div>
          </div>

          <div className="card p-6">
            <div className="flex items-center">
              <Percent className="h-8 w-8 text-blue-500" />
              <div className="ml-4">
                <p className="text-sm text-gray-600">Pool Utilization</p>
                <p className="text-2xl font-bold text-blue-600">{poolStats.utilization}%</p>
              </div>
            </div>
          </div>

          <div className="card p-6">
            <div className="flex items-center">
              <TrendingUp className="h-8 w-8 text-purple-500" />
              <div className="ml-4">
                <p className="text-sm text-gray-600">Your Total Deposits</p>
                <p className="text-2xl font-bold text-gray-900">
                  {formatCurrency(poolStats.seniorTranche.userDeposits + poolStats.juniorTranche.userDeposits)}
                </p>
              </div>
            </div>
          </div>

          <div className="card p-6">
            <div className="flex items-center">
              <DollarSign className="h-8 w-8 text-green-500" />
              <div className="ml-4">
                <p className="text-sm text-gray-600">Total Yield Earned</p>
                <p className="text-2xl font-bold text-green-600">
                  {formatCurrency(poolStats.seniorTranche.currentYield + poolStats.juniorTranche.currentYield)}
                </p>
              </div>
            </div>
          </div>
        </div>

        {/* Tabs */}
        <div className="mb-8">
          <div className="border-b border-gray-200">
            <nav className="-mb-px flex space-x-8">
              {[
                { key: 'overview', label: 'Overview' },
                { key: 'senior', label: 'Senior Tranche' },
                { key: 'junior', label: 'Junior Tranche' },
                { key: 'history', label: 'History' },
              ].map(({ key, label }) => (
                <button
                  key={key}
                  onClick={() => setActiveTab(key as any)}
                  className={`py-2 px-1 border-b-2 font-medium text-sm ${
                    activeTab === key
                      ? 'border-blue-500 text-blue-600'
                      : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
                  }`}
                >
                  {label}
                </button>
              ))}
            </nav>
          </div>
        </div>

        {/* Tab Content */}
        {activeTab === 'overview' && (
          <div className="space-y-8">
            {/* Waterfall Distribution Explanation */}
            <div className="card p-6">
              <h3 className="text-lg font-semibold text-gray-900 mb-4">
                Waterfall Distribution Model
              </h3>
              <div className="bg-blue-50 border border-blue-200 rounded p-4 mb-4">
                <div className="flex items-start">
                  <Info className="h-5 w-5 text-blue-600 mt-0.5 mr-3 flex-shrink-0" />
                  <div>
                    <p className="text-sm text-blue-800 font-medium">How Yield Distribution Works</p>
                    <p className="text-sm text-blue-700 mt-1">
                      Senior tranche holders receive their target yield first, then junior tranche holders receive excess returns. 
                      This structure provides predictable returns for senior investors and higher potential yields for junior investors.
                    </p>
                  </div>
                </div>
              </div>
              
              <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                <div className="border border-blue-200 rounded p-4">
                  <h4 className="font-semibold text-blue-900 mb-2">Senior Tranche Priority</h4>
                  <ul className="text-sm text-blue-700 space-y-1">
                    <li>• Receives yield distributions first</li>
                    <li>• Lower risk, stable returns</li>
                    <li>• Target APY: {poolStats.seniorTranche.yieldRate}%</li>
                    <li>• 90-day lockup period</li>
                  </ul>
                </div>
                
                <div className="border border-purple-200 rounded p-4">
                  <h4 className="font-semibold text-purple-900 mb-2">Junior Tranche Excess</h4>
                  <ul className="text-sm text-purple-700 space-y-1">
                    <li>• Receives remaining yield after senior</li>
                    <li>• Higher risk, variable returns</li>
                    <li>• Current APY: {poolStats.juniorTranche.yieldRate}%</li>
                    <li>• 180-day lockup period</li>
                  </ul>
                </div>
              </div>
            </div>

            {/* Tranches Side by Side */}
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
              <TrancheCard tranche={poolStats.seniorTranche} />
              <TrancheCard tranche={poolStats.juniorTranche} />
            </div>
          </div>
        )}

        {activeTab === 'senior' && (
          <div className="space-y-6">
            <TrancheCard tranche={poolStats.seniorTranche} />
            
            <div className="card p-6">
              <h3 className="text-lg font-semibold text-gray-900 mb-4">Senior Tranche Performance</h3>
              <div className="h-64 flex items-center justify-center bg-gray-50 rounded">
                <div className="text-center">
                  <TrendingUp className="h-12 w-12 text-gray-400 mx-auto mb-2" />
                  <p className="text-gray-500">Performance chart would display here</p>
                  <p className="text-sm text-gray-400 mt-1">Historical APY and yield distribution data</p>
                </div>
              </div>
            </div>
          </div>
        )}

        {activeTab === 'junior' && (
          <div className="space-y-6">
            <TrancheCard tranche={poolStats.juniorTranche} />
            
            <div className="card p-6">
              <h3 className="text-lg font-semibold text-gray-900 mb-4">Junior Tranche Performance</h3>
              <div className="h-64 flex items-center justify-center bg-gray-50 rounded">
                <div className="text-center">
                  <TrendingUp className="h-12 w-12 text-gray-400 mx-auto mb-2" />
                  <p className="text-gray-500">Performance chart would display here</p>
                  <p className="text-sm text-gray-400 mt-1">Historical APY variability and excess returns</p>
                </div>
              </div>
            </div>
          </div>
        )}

        {activeTab === 'history' && (
          <div className="card p-6">
            <h3 className="text-lg font-semibold text-gray-900 mb-4">Transaction History</h3>
            <div className="space-y-4">
              <div className="flex items-center justify-between p-4 border border-gray-200 rounded">
                <div className="flex items-center space-x-3">
                  <div className="p-2 bg-green-100 rounded">
                    <Plus className="h-4 w-4 text-green-600" />
                  </div>
                  <div>
                    <p className="font-medium text-gray-900">Senior Tranche Deposit</p>
                    <p className="text-sm text-gray-600">Deposited $50,000 to senior tranche</p>
                  </div>
                </div>
                <div className="text-right">
                  <p className="font-medium text-gray-900">+$50,000</p>
                  <p className="text-sm text-gray-500">Mar 15, 2024</p>
                </div>
              </div>
              
              <div className="flex items-center justify-between p-4 border border-gray-200 rounded">
                <div className="flex items-center space-x-3">
                  <div className="p-2 bg-purple-100 rounded">
                    <Plus className="h-4 w-4 text-purple-600" />
                  </div>
                  <div>
                    <p className="font-medium text-gray-900">Junior Tranche Deposit</p>
                    <p className="text-sm text-gray-600">Deposited $25,000 to junior tranche</p>
                  </div>
                </div>
                <div className="text-right">
                  <p className="font-medium text-gray-900">+$25,000</p>
                  <p className="text-sm text-gray-500">Mar 20, 2024</p>
                </div>
              </div>
              
              <div className="flex items-center justify-between p-4 border border-gray-200 rounded">
                <div className="flex items-center space-x-3">
                  <div className="p-2 bg-green-100 rounded">
                    <DollarSign className="h-4 w-4 text-green-600" />
                  </div>
                  <div>
                    <p className="font-medium text-gray-900">Yield Distribution</p>
                    <p className="text-sm text-gray-600">Monthly yield payment received</p>
                  </div>
                </div>
                <div className="text-right">
                  <p className="font-medium text-green-600">+$4,275</p>
                  <p className="text-sm text-gray-500">Apr 1, 2024</p>
                </div>
              </div>
            </div>
          </div>
        )}

        {/* Risk Disclosure */}
        <div className="card p-6 bg-yellow-50 border-yellow-200 mt-8">
          <div className="flex items-start">
            <Info className="h-5 w-5 text-yellow-600 mt-0.5 mr-3 flex-shrink-0" />
            <div>
              <h4 className="font-semibold text-yellow-800">Investment Risk Disclosure</h4>
              <p className="text-sm text-yellow-700 mt-1">
                Liquidity pool investments carry inherent risks including potential loss of principal, 
                yield variability, and lockup periods. Junior tranche investments are higher risk with 
                variable returns. Past performance does not guarantee future results. Please consult 
                with a qualified financial advisor before investing.
              </p>
            </div>
          </div>
        </div>
      </main>
    </div>
  )
}