'use client'

import { Shield, Users, Globe, Lock } from 'lucide-react'

interface ComplianceStatusProps {
  detailed?: boolean
}

export default function ComplianceStatus({ detailed = false }: ComplianceStatusProps) {
  // Mock data - in real implementation, this would come from compliance registry
  const complianceData = {
    totalUsers: 1247,
    kycVerified: 1189,
    accreditedInvestors: 892,
    activeJurisdictions: ['US', 'UK', 'EU', 'CA', 'AU', 'SG', 'CH'],
    rule144Active: 156
  }

  const jurisdictionStats = [
    { country: 'United States', code: 'US', users: 523, percentage: 42.0 },
    { country: 'United Kingdom', code: 'UK', users: 287, percentage: 23.0 },
    { country: 'European Union', code: 'EU', users: 198, percentage: 15.9 },
    { country: 'Canada', code: 'CA', users: 134, percentage: 10.7 },
    { country: 'Australia', code: 'AU', users: 67, percentage: 5.4 },
    { country: 'Singapore', code: 'SG', users: 25, percentage: 2.0 },
    { country: 'Switzerland', code: 'CH', users: 13, percentage: 1.0 }
  ]

  const recentActivity = [
    { type: 'KYC_APPROVED', user: '0x1234...5678', jurisdiction: 'US', time: '5m ago' },
    { type: 'ACCREDITATION_VERIFIED', user: '0x9876...5432', jurisdiction: 'UK', time: '12m ago' },
    { type: 'RULE144_EXPIRED', user: '0xabcd...efgh', jurisdiction: 'EU', time: '23m ago' },
    { type: 'KYC_APPROVED', user: '0x5555...7777', jurisdiction: 'CA', time: '31m ago' }
  ]

  const complianceScore = Math.round((complianceData.kycVerified / complianceData.totalUsers) * 100)

  return (
    <div className="bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 p-6">
      <div className="flex items-center justify-between mb-6">
        <h3 className="text-lg font-semibold text-slate-900 dark:text-white flex items-center space-x-2">
          <Shield className="h-5 w-5 text-green-500" />
          <span>Compliance Status</span>
        </h3>
        <div className="flex items-center space-x-2">
          <div className="text-2xl font-bold text-green-600 dark:text-green-400">{complianceScore}%</div>
          <div className="text-sm text-slate-500 dark:text-slate-400">Compliant</div>
        </div>
      </div>

      {/* Compliance Metrics */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">
        <div className="text-center">
          <div className="w-12 h-12 bg-blue-100 dark:bg-blue-900/30 rounded-lg flex items-center justify-center mx-auto mb-2">
            <Users className="h-6 w-6 text-blue-600 dark:text-blue-400" />
          </div>
          <div className="text-lg font-semibold text-slate-900 dark:text-white">{complianceData.totalUsers}</div>
          <div className="text-xs text-slate-500 dark:text-slate-400">Total Users</div>
        </div>

        <div className="text-center">
          <div className="w-12 h-12 bg-green-100 dark:bg-green-900/30 rounded-lg flex items-center justify-center mx-auto mb-2">
            <Shield className="h-6 w-6 text-green-600 dark:text-green-400" />
          </div>
          <div className="text-lg font-semibold text-slate-900 dark:text-white">{complianceData.kycVerified}</div>
          <div className="text-xs text-slate-500 dark:text-slate-400">KYC Verified</div>
        </div>

        <div className="text-center">
          <div className="w-12 h-12 bg-purple-100 dark:bg-purple-900/30 rounded-lg flex items-center justify-center mx-auto mb-2">
            <Globe className="h-6 w-6 text-purple-600 dark:text-purple-400" />
          </div>
          <div className="text-lg font-semibold text-slate-900 dark:text-white">{complianceData.activeJurisdictions.length}</div>
          <div className="text-xs text-slate-500 dark:text-slate-400">Jurisdictions</div>
        </div>

        <div className="text-center">
          <div className="w-12 h-12 bg-orange-100 dark:bg-orange-900/30 rounded-lg flex items-center justify-center mx-auto mb-2">
            <Lock className="h-6 w-6 text-orange-600 dark:text-orange-400" />
          </div>
          <div className="text-lg font-semibold text-slate-900 dark:text-white">{complianceData.rule144Active}</div>
          <div className="text-xs text-slate-500 dark:text-slate-400">Rule 144 Active</div>
        </div>
      </div>

      {detailed ? (
        <>
          {/* Jurisdiction Breakdown */}
          <div className="mb-6">
            <h4 className="font-medium text-slate-900 dark:text-white mb-3">Jurisdiction Distribution</h4>
            <div className="space-y-3">
              {jurisdictionStats.map((jurisdiction) => (
                <div key={jurisdiction.code} className="flex items-center justify-between">
                  <div className="flex items-center space-x-3">
                    <div className="w-6 h-4 bg-gradient-to-r from-blue-500 to-purple-500 rounded-sm flex items-center justify-center">
                      <span className="text-xs font-bold text-white">{jurisdiction.code}</span>
                    </div>
                    <span className="text-sm text-slate-700 dark:text-slate-300">{jurisdiction.country}</span>
                  </div>
                  <div className="flex items-center space-x-3">
                    <div className="w-24 bg-slate-200 dark:bg-slate-600 rounded-full h-2">
                      <div 
                        className="bg-gradient-to-r from-blue-500 to-purple-500 h-2 rounded-full"
                        style={{ width: `${jurisdiction.percentage}%` }}
                      ></div>
                    </div>
                    <div className="text-sm font-medium text-slate-900 dark:text-white w-12 text-right">
                      {jurisdiction.users}
                    </div>
                    <div className="text-xs text-slate-500 dark:text-slate-400 w-10 text-right">
                      {jurisdiction.percentage}%
                    </div>
                  </div>
                </div>
              ))}
            </div>
          </div>

          {/* Recent Activity */}
          <div>
            <h4 className="font-medium text-slate-900 dark:text-white mb-3">Recent Compliance Activity</h4>
            <div className="space-y-2">
              {recentActivity.map((activity, index) => {
                const getActivityDetails = (type: string) => {
                  switch (type) {
                    case 'KYC_APPROVED':
                      return { label: 'KYC Approved', color: 'green', icon: Shield }
                    case 'ACCREDITATION_VERIFIED':
                      return { label: 'Accreditation Verified', color: 'blue', icon: Users }
                    case 'RULE144_EXPIRED':
                      return { label: 'Rule 144 Lockup Expired', color: 'orange', icon: Lock }
                    default:
                      return { label: 'Unknown', color: 'gray', icon: Shield }
                  }
                }

                const details = getActivityDetails(activity.type)
                const Icon = details.icon

                return (
                  <div key={index} className="flex items-center justify-between p-3 bg-slate-50 dark:bg-slate-700/50 rounded-lg">
                    <div className="flex items-center space-x-3">
                      <div className={`w-8 h-8 bg-${details.color}-100 dark:bg-${details.color}-900/30 rounded-lg flex items-center justify-center`}>
                        <Icon className={`h-4 w-4 text-${details.color}-600 dark:text-${details.color}-400`} />
                      </div>
                      <div>
                        <p className="text-sm font-medium text-slate-900 dark:text-white">{details.label}</p>
                        <p className="text-xs text-slate-500 dark:text-slate-400">
                          {activity.user} • {activity.jurisdiction}
                        </p>
                      </div>
                    </div>
                    <div className="text-xs text-slate-500 dark:text-slate-400">
                      {activity.time}
                    </div>
                  </div>
                )
              })}
            </div>
          </div>
        </>
      ) : (
        /* Summary View */
        <div className="space-y-4">
          <div className="flex items-center justify-between p-3 bg-green-50 dark:bg-green-900/20 rounded-lg">
            <div className="flex items-center space-x-2">
              <div className="w-2 h-2 bg-green-500 rounded-full"></div>
              <span className="text-sm font-medium text-green-900 dark:text-green-100">
                {complianceData.kycVerified} KYC Verified Users
              </span>
            </div>
            <span className="text-sm text-green-700 dark:text-green-300">
              {complianceScore}% compliance rate
            </span>
          </div>
          
          <div className="flex items-center justify-between p-3 bg-blue-50 dark:bg-blue-900/20 rounded-lg">
            <div className="flex items-center space-x-2">
              <div className="w-2 h-2 bg-blue-500 rounded-full"></div>
              <span className="text-sm font-medium text-blue-900 dark:text-blue-100">
                {complianceData.accreditedInvestors} Accredited Investors
              </span>
            </div>
            <span className="text-sm text-blue-700 dark:text-blue-300">
              {Math.round((complianceData.accreditedInvestors / complianceData.totalUsers) * 100)}% of users
            </span>
          </div>
        </div>
      )}
    </div>
  )
}