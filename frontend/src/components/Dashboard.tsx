'use client'

import { useState } from 'react'
import StatsOverview from './StatsOverview'
import OracleStatus from './OracleStatus'
import ComplianceStatus from './ComplianceStatus'
import VaultMetrics from './VaultMetrics'
import LiquidityPool from './LiquidityPool'
import AttestationHistory from './AttestationHistory'
import RiskMetrics from './RiskMetrics'

export default function Dashboard() {
  const [activeTab, setActiveTab] = useState('overview')

  const tabs = [
    { id: 'overview', name: 'Overview', icon: '📊' },
    { id: 'vault', name: 'Vault', icon: '🏦' },
    { id: 'pool', name: 'Liquidity Pool', icon: '💧' },
    { id: 'compliance', name: 'Compliance', icon: '🛡️' },
    { id: 'oracle', name: 'Oracle', icon: '🔮' },
    { id: 'risk', name: 'Risk', icon: '⚠️' }
  ]

  return (
    <div className="space-y-6">
      {/* Hero Section */}
      <div className="text-center space-y-4">
        <h1 className="text-4xl font-bold bg-gradient-to-r from-blue-600 via-purple-600 to-emerald-600 bg-clip-text text-transparent">
          iYield Protocol Dashboard
        </h1>
        <p className="text-xl text-slate-600 dark:text-slate-300 max-w-3xl mx-auto">
          Real-time transparency for insurance cash surrender value backed securities with 
          <span className="font-semibold text-blue-600"> Proof-of-CSV™</span> attestations
        </p>
      </div>

      {/* Quick Stats */}
      <StatsOverview />

      {/* Tab Navigation */}
      <div className="flex flex-wrap justify-center gap-2 p-2 bg-slate-100 dark:bg-slate-800 rounded-xl">
        {tabs.map((tab) => (
          <button
            key={tab.id}
            onClick={() => setActiveTab(tab.id)}
            className={`flex items-center space-x-2 px-4 py-2 rounded-lg font-medium transition-all duration-200 ${
              activeTab === tab.id
                ? 'bg-white dark:bg-slate-700 text-blue-600 dark:text-blue-400 shadow-sm'
                : 'text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-slate-200'
            }`}
          >
            <span>{tab.icon}</span>
            <span>{tab.name}</span>
          </button>
        ))}
      </div>

      {/* Tab Content */}
      <div className="min-h-[600px]">
        {activeTab === 'overview' && (
          <div className="space-y-6">
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
              <OracleStatus />
              <ComplianceStatus />
            </div>
            <VaultMetrics />
            <AttestationHistory />
          </div>
        )}

        {activeTab === 'vault' && (
          <VaultMetrics detailed />
        )}

        {activeTab === 'pool' && (
          <LiquidityPool />
        )}

        {activeTab === 'compliance' && (
          <ComplianceStatus detailed />
        )}

        {activeTab === 'oracle' && (
          <div className="space-y-6">
            <OracleStatus detailed />
            <AttestationHistory />
          </div>
        )}

        {activeTab === 'risk' && (
          <RiskMetrics />
        )}
      </div>
    </div>
  )
}