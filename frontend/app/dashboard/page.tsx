'use client'

import { useState, useEffect } from 'react'
import { TrendingUp, Shield, Users, DollarSign, Activity, AlertCircle } from 'lucide-react'

interface DashboardStats {
  totalValueLocked: number
  activeVaults: number
  totalUsers: number
  yieldGenerated: number
  oracleStatus: 'operational' | 'warning' | 'error'
  complianceRate: number
}

export default function DashboardPage() {
  const [stats, setStats] = useState<DashboardStats>({
    totalValueLocked: 0,
    activeVaults: 0,
    totalUsers: 0,
    yieldGenerated: 0,
    oracleStatus: 'operational',
    complianceRate: 100
  })

  const [loading, setLoading] = useState(true)

  useEffect(() => {
    // Simulate loading dashboard data
    const loadDashboardData = async () => {
      setLoading(true)
      
      // Simulate API call
      await new Promise(resolve => setTimeout(resolve, 1000))
      
      setStats({
        totalValueLocked: 2750000,
        activeVaults: 156,
        totalUsers: 89,
        yieldGenerated: 187500,
        oracleStatus: 'operational',
        complianceRate: 98.7
      })
      
      setLoading(false)
    }

    loadDashboardData()
  }, [])

  const formatCurrency = (amount: number) => {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD',
      minimumFractionDigits: 0,
      maximumFractionDigits: 0,
    }).format(amount)
  }

  const StatCard = ({ title, value, icon: Icon, trend, className = "" }) => (
    <div className={`card p-6 ${className}`}>
      <div className="flex items-center justify-between">
        <div>
          <p className="text-sm text-gray-600">{title}</p>
          <p className="text-2xl font-bold text-gray-900 mt-1">{value}</p>
          {trend && (
            <div className="flex items-center mt-2 text-sm">
              <TrendingUp className="h-4 w-4 text-green-500 mr-1" />
              <span className="text-green-600">{trend}</span>
            </div>
          )}
        </div>
        <div className="p-3 rounded-full bg-blue-50">
          <Icon className="h-6 w-6 text-blue-600" />
        </div>
      </div>
    </div>
  )

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'operational':
        return 'text-green-600 bg-green-100'
      case 'warning':
        return 'text-yellow-600 bg-yellow-100'
      case 'error':
        return 'text-red-600 bg-red-100'
      default:
        return 'text-gray-600 bg-gray-100'
    }
  }

  if (loading) {
    return (
      <div className="min-h-screen bg-gray-50 p-6">
        <div className="max-w-7xl mx-auto">
          <div className="animate-pulse">
            <div className="h-8 bg-gray-200 rounded w-1/4 mb-6"></div>
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
              {[...Array(4)].map((_, i) => (
                <div key={i} className="h-32 bg-gray-200 rounded"></div>
              ))}
            </div>
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
              <div className="h-96 bg-gray-200 rounded"></div>
              <div className="h-96 bg-gray-200 rounded"></div>
            </div>
          </div>
        </div>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Header */}
      <header className="bg-white border-b border-gray-200">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between items-center h-16">
            <div className="flex items-center">
              <h1 className="text-2xl font-bold text-gray-900">
                iYield Protocol™ Dashboard
              </h1>
            </div>
            <div className="flex items-center space-x-4">
              <div className={`flex items-center space-x-2 px-3 py-1 rounded-full ${getStatusColor(stats.oracleStatus)}`}>
                <Activity className="h-4 w-4" />
                <span className="text-sm font-medium capitalize">{stats.oracleStatus}</span>
              </div>
            </div>
          </div>
        </div>
      </header>

      {/* Main Content */}
      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {/* Stats Grid */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
          <StatCard
            title="Total Value Locked"
            value={formatCurrency(stats.totalValueLocked)}
            icon={DollarSign}
            trend="+12.3% from last month"
          />
          
          <StatCard
            title="Active Vaults"
            value={stats.activeVaults.toLocaleString()}
            icon={Shield}
            trend="+8 new this week"
          />
          
          <StatCard
            title="Verified Users"
            value={stats.totalUsers.toLocaleString()}
            icon={Users}
            trend="+5.2% growth"
          />
          
          <StatCard
            title="Yield Generated"
            value={formatCurrency(stats.yieldGenerated)}
            icon={TrendingUp}
            trend="+18.7% this quarter"
          />
        </div>

        {/* Charts and Activity */}
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-8 mb-8">
          {/* TVL Chart */}
          <div className="card p-6">
            <h3 className="text-lg font-semibold text-gray-900 mb-4">
              Total Value Locked Trend
            </h3>
            <div className="h-64 flex items-center justify-center bg-gray-50 rounded">
              <div className="text-center">
                <TrendingUp className="h-12 w-12 text-gray-400 mx-auto mb-2" />
                <p className="text-gray-500">Chart visualization would go here</p>
                <p className="text-sm text-gray-400 mt-1">Integration with Recharts or similar</p>
              </div>
            </div>
          </div>

          {/* Recent Activity */}
          <div className="card p-6">
            <h3 className="text-lg font-semibold text-gray-900 mb-4">
              Recent Activity
            </h3>
            <div className="space-y-4">
              <div className="flex items-center space-x-3 p-3 bg-green-50 rounded">
                <Shield className="h-5 w-5 text-green-600" />
                <div className="flex-1">
                  <p className="text-sm text-gray-900">New vault opened</p>
                  <p className="text-xs text-gray-600">Policy #789012 • $45,000 CSV</p>
                </div>
                <span className="text-xs text-gray-500">2 min ago</span>
              </div>
              
              <div className="flex items-center space-x-3 p-3 bg-blue-50 rounded">
                <Users className="h-5 w-5 text-blue-600" />
                <div className="flex-1">
                  <p className="text-sm text-gray-900">User KYC approved</p>
                  <p className="text-xs text-gray-600">Accredited investor verified</p>
                </div>
                <span className="text-xs text-gray-500">15 min ago</span>
              </div>
              
              <div className="flex items-center space-x-3 p-3 bg-purple-50 rounded">
                <DollarSign className="h-5 w-5 text-purple-600" />
                <div className="flex-1">
                  <p className="text-sm text-gray-900">Yield distribution</p>
                  <p className="text-xs text-gray-600">$12,500 distributed to liquidity providers</p>
                </div>
                <span className="text-xs text-gray-500">1 hour ago</span>
              </div>
              
              <div className="flex items-center space-x-3 p-3 bg-yellow-50 rounded">
                <AlertCircle className="h-5 w-5 text-yellow-600" />
                <div className="flex-1">
                  <p className="text-sm text-gray-900">Oracle valuation update</p>
                  <p className="text-xs text-gray-600">Policy #654321 revalued</p>
                </div>
                <span className="text-xs text-gray-500">2 hours ago</span>
              </div>
            </div>
          </div>
        </div>

        {/* System Status */}
        <div className="card p-6">
          <h3 className="text-lg font-semibold text-gray-900 mb-4">
            System Status
          </h3>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
            <div className="text-center">
              <div className="inline-flex items-center justify-center w-12 h-12 bg-green-100 rounded-full mb-3">
                <Shield className="h-6 w-6 text-green-600" />
              </div>
              <h4 className="font-semibold text-gray-900">Oracle Network</h4>
              <p className="text-sm text-gray-600 mt-1">7/7 Oracles Online</p>
              <p className="text-xs text-green-600 mt-1">Fully Operational</p>
            </div>
            
            <div className="text-center">
              <div className="inline-flex items-center justify-center w-12 h-12 bg-green-100 rounded-full mb-3">
                <Users className="h-6 w-6 text-green-600" />
              </div>
              <h4 className="font-semibold text-gray-900">Compliance Rate</h4>
              <p className="text-sm text-gray-600 mt-1">{stats.complianceRate}% Verified</p>
              <p className="text-xs text-green-600 mt-1">Excellent</p>
            </div>
            
            <div className="text-center">
              <div className="inline-flex items-center justify-center w-12 h-12 bg-green-100 rounded-full mb-3">
                <Activity className="h-6 w-6 text-green-600" />
              </div>
              <h4 className="font-semibold text-gray-900">Network Health</h4>
              <p className="text-sm text-gray-600 mt-1">0.99% Uptime</p>
              <p className="text-xs text-green-600 mt-1">Stable</p>
            </div>
          </div>
        </div>

        {/* Quick Actions */}
        <div className="card p-6 mt-8">
          <h3 className="text-lg font-semibold text-gray-900 mb-4">
            Quick Actions
          </h3>
          <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
            <button className="btn btn-primary">
              Open New Vault
            </button>
            <button className="btn btn-secondary">
              Request Valuation
            </button>
            <button className="btn btn-secondary">
              View Compliance
            </button>
            <button className="btn btn-secondary">
              Manage Liquidity
            </button>
          </div>
        </div>
      </main>
    </div>
  )
}