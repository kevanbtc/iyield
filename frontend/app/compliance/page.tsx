'use client'

import { useState } from 'react'
import { CheckCircle, XCircle, Clock, Shield, AlertTriangle, FileText, Users } from 'lucide-react'

interface ComplianceStatus {
  isKYCVerified: boolean
  isAccredited: boolean
  kycExpiry: string
  accreditationExpiry: string
  jurisdictionCode: number
  jurisdictionName: string
  lockupExpiry: string
  isRestricted: boolean
  complianceScore: number
}

export default function CompliancePage() {
  const [userCompliance, setUserCompliance] = useState<ComplianceStatus>({
    isKYCVerified: true,
    isAccredited: true,
    kycExpiry: '2024-12-15',
    accreditationExpiry: '2025-03-20',
    jurisdictionCode: 1,
    jurisdictionName: 'United States',
    lockupExpiry: '2024-10-15',
    isRestricted: false,
    complianceScore: 95
  })

  const [activeTab, setActiveTab] = useState<'status' | 'documents' | 'history'>('status')

  const StatusIcon = ({ status, className = "h-5 w-5" }) => {
    switch (status) {
      case 'verified':
        return <CheckCircle className={`${className} text-green-500`} />
      case 'expired':
        return <XCircle className={`${className} text-red-500`} />
      case 'pending':
        return <Clock className={`${className} text-yellow-500`} />
      default:
        return <XCircle className={`${className} text-gray-400`} />
    }
  }

  const getStatusText = (status: string) => {
    switch (status) {
      case 'verified':
        return 'Verified'
      case 'expired':
        return 'Expired'
      case 'pending':
        return 'Pending'
      default:
        return 'Not Verified'
    }
  }

  const isDateExpired = (dateStr: string) => {
    return new Date(dateStr) < new Date()
  }

  const getKYCStatus = () => {
    if (!userCompliance.isKYCVerified) return 'not-verified'
    if (isDateExpired(userCompliance.kycExpiry)) return 'expired'
    return 'verified'
  }

  const getAccreditationStatus = () => {
    if (!userCompliance.isAccredited) return 'not-verified'
    if (isDateExpired(userCompliance.accreditationExpiry)) return 'expired'
    return 'verified'
  }

  const ComplianceCard = ({ title, status, expiry, description, actionText, onAction }) => (
    <div className="card p-6">
      <div className="flex items-start justify-between">
        <div className="flex items-start space-x-3">
          <StatusIcon status={status} />
          <div className="flex-1">
            <h3 className="text-lg font-semibold text-gray-900">{title}</h3>
            <p className="text-sm text-gray-600 mt-1">{description}</p>
            {expiry && (
              <p className="text-xs text-gray-500 mt-2">
                Expires: {new Date(expiry).toLocaleDateString()}
              </p>
            )}
            <div className="flex items-center mt-2">
              <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${
                status === 'verified' ? 'bg-green-100 text-green-800' :
                status === 'expired' ? 'bg-red-100 text-red-800' :
                status === 'pending' ? 'bg-yellow-100 text-yellow-800' :
                'bg-gray-100 text-gray-800'
              }`}>
                {getStatusText(status)}
              </span>
            </div>
          </div>
        </div>
        <button 
          onClick={onAction}
          className="btn btn-primary text-sm"
        >
          {actionText}
        </button>
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
              <Shield className="h-6 w-6 text-blue-600 mr-3" />
              <h1 className="text-2xl font-bold text-gray-900">
                Compliance Center
              </h1>
            </div>
            <div className="flex items-center space-x-4">
              <div className="text-right">
                <p className="text-sm text-gray-600">Compliance Score</p>
                <p className="text-lg font-bold text-green-600">{userCompliance.complianceScore}%</p>
              </div>
            </div>
          </div>
        </div>
      </header>

      {/* Main Content */}
      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        
        {/* Compliance Overview */}
        <div className="card p-6 mb-8">
          <h2 className="text-lg font-semibold text-gray-900 mb-4">Compliance Overview</h2>
          <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
            <div className="text-center">
              <div className="inline-flex items-center justify-center w-12 h-12 bg-blue-100 rounded-full mb-3">
                <Users className="h-6 w-6 text-blue-600" />
              </div>
              <h4 className="font-semibold text-gray-900">KYC Status</h4>
              <p className={`text-sm mt-1 ${getKYCStatus() === 'verified' ? 'text-green-600' : 'text-red-600'}`}>
                {getStatusText(getKYCStatus())}
              </p>
            </div>
            
            <div className="text-center">
              <div className="inline-flex items-center justify-center w-12 h-12 bg-green-100 rounded-full mb-3">
                <Shield className="h-6 w-6 text-green-600" />
              </div>
              <h4 className="font-semibold text-gray-900">Accreditation</h4>
              <p className={`text-sm mt-1 ${getAccreditationStatus() === 'verified' ? 'text-green-600' : 'text-red-600'}`}>
                {getStatusText(getAccreditationStatus())}
              </p>
            </div>
            
            <div className="text-center">
              <div className="inline-flex items-center justify-center w-12 h-12 bg-purple-100 rounded-full mb-3">
                <FileText className="h-6 w-6 text-purple-600" />
              </div>
              <h4 className="font-semibold text-gray-900">Jurisdiction</h4>
              <p className="text-sm text-gray-600 mt-1">{userCompliance.jurisdictionName}</p>
            </div>
            
            <div className="text-center">
              <div className={`inline-flex items-center justify-center w-12 h-12 rounded-full mb-3 ${
                userCompliance.isRestricted ? 'bg-red-100' : 'bg-green-100'
              }`}>
                <AlertTriangle className={`h-6 w-6 ${
                  userCompliance.isRestricted ? 'text-red-600' : 'text-green-600'
                }`} />
              </div>
              <h4 className="font-semibold text-gray-900">Account Status</h4>
              <p className={`text-sm mt-1 ${
                userCompliance.isRestricted ? 'text-red-600' : 'text-green-600'
              }`}>
                {userCompliance.isRestricted ? 'Restricted' : 'Active'}
              </p>
            </div>
          </div>
        </div>

        {/* Tabs */}
        <div className="mb-8">
          <div className="border-b border-gray-200">
            <nav className="-mb-px flex space-x-8">
              {[
                { key: 'status', label: 'Compliance Status', icon: CheckCircle },
                { key: 'documents', label: 'Documents', icon: FileText },
                { key: 'history', label: 'History', icon: Clock },
              ].map(({ key, label, icon: Icon }) => (
                <button
                  key={key}
                  onClick={() => setActiveTab(key as any)}
                  className={`flex items-center py-2 px-1 border-b-2 font-medium text-sm ${
                    activeTab === key
                      ? 'border-blue-500 text-blue-600'
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
        {activeTab === 'status' && (
          <div className="space-y-6">
            <ComplianceCard
              title="KYC Verification"
              status={getKYCStatus()}
              expiry={userCompliance.kycExpiry}
              description="Know Your Customer verification ensures regulatory compliance and user identity validation."
              actionText="Renew KYC"
              onAction={() => console.log('Renew KYC')}
            />
            
            <ComplianceCard
              title="Accredited Investor Status"
              status={getAccreditationStatus()}
              expiry={userCompliance.accreditationExpiry}
              description="Verification of accredited investor status as required by SEC regulations for security token investments."
              actionText="Update Status"
              onAction={() => console.log('Update accreditation')}
            />
            
            <div className="card p-6">
              <div className="flex items-start justify-between">
                <div className="flex items-start space-x-3">
                  <Clock className="h-5 w-5 text-yellow-500 mt-0.5" />
                  <div className="flex-1">
                    <h3 className="text-lg font-semibold text-gray-900">Rule 144 Lockup Period</h3>
                    <p className="text-sm text-gray-600 mt-1">
                      Securities holding period as required by Rule 144 for restricted securities transfers.
                    </p>
                    <p className="text-xs text-gray-500 mt-2">
                      Lockup expires: {new Date(userCompliance.lockupExpiry).toLocaleDateString()}
                    </p>
                    <div className="flex items-center mt-2">
                      <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${
                        isDateExpired(userCompliance.lockupExpiry) 
                          ? 'bg-green-100 text-green-800' 
                          : 'bg-yellow-100 text-yellow-800'
                      }`}>
                        {isDateExpired(userCompliance.lockupExpiry) ? 'Unlocked' : 'Locked'}
                      </span>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        )}

        {activeTab === 'documents' && (
          <div className="card p-6">
            <h3 className="text-lg font-semibold text-gray-900 mb-4">Required Documents</h3>
            <div className="space-y-4">
              <div className="flex items-center justify-between p-4 border border-gray-200 rounded">
                <div className="flex items-center space-x-3">
                  <FileText className="h-5 w-5 text-blue-600" />
                  <div>
                    <p className="font-medium text-gray-900">Identity Verification</p>
                    <p className="text-sm text-gray-600">Government-issued photo ID</p>
                  </div>
                </div>
                <div className="flex items-center space-x-2">
                  <CheckCircle className="h-5 w-5 text-green-500" />
                  <span className="text-sm text-green-600">Verified</span>
                </div>
              </div>
              
              <div className="flex items-center justify-between p-4 border border-gray-200 rounded">
                <div className="flex items-center space-x-3">
                  <FileText className="h-5 w-5 text-blue-600" />
                  <div>
                    <p className="font-medium text-gray-900">Accreditation Certificate</p>
                    <p className="text-sm text-gray-600">SEC accredited investor verification</p>
                  </div>
                </div>
                <div className="flex items-center space-x-2">
                  <CheckCircle className="h-5 w-5 text-green-500" />
                  <span className="text-sm text-green-600">Verified</span>
                </div>
              </div>
              
              <div className="flex items-center justify-between p-4 border border-gray-200 rounded">
                <div className="flex items-center space-x-3">
                  <FileText className="h-5 w-5 text-blue-600" />
                  <div>
                    <p className="font-medium text-gray-900">Address Verification</p>
                    <p className="text-sm text-gray-600">Proof of residential address</p>
                  </div>
                </div>
                <div className="flex items-center space-x-2">
                  <CheckCircle className="h-5 w-5 text-green-500" />
                  <span className="text-sm text-green-600">Verified</span>
                </div>
              </div>
            </div>
          </div>
        )}

        {activeTab === 'history' && (
          <div className="card p-6">
            <h3 className="text-lg font-semibold text-gray-900 mb-4">Compliance History</h3>
            <div className="space-y-4">
              <div className="flex items-start space-x-3 p-4 bg-green-50 rounded">
                <CheckCircle className="h-5 w-5 text-green-600 mt-0.5" />
                <div className="flex-1">
                  <p className="font-medium text-gray-900">KYC Verification Completed</p>
                  <p className="text-sm text-gray-600">Identity and address verification approved</p>
                  <p className="text-xs text-gray-500 mt-1">March 15, 2024</p>
                </div>
              </div>
              
              <div className="flex items-start space-x-3 p-4 bg-blue-50 rounded">
                <Shield className="h-5 w-5 text-blue-600 mt-0.5" />
                <div className="flex-1">
                  <p className="font-medium text-gray-900">Accredited Investor Status Verified</p>
                  <p className="text-sm text-gray-600">SEC accreditation confirmed through third-party verification</p>
                  <p className="text-xs text-gray-500 mt-1">March 20, 2024</p>
                </div>
              </div>
              
              <div className="flex items-start space-x-3 p-4 bg-yellow-50 rounded">
                <Clock className="h-5 w-5 text-yellow-600 mt-0.5" />
                <div className="flex-1">
                  <p className="font-medium text-gray-900">Rule 144 Lockup Period Started</p>
                  <p className="text-sm text-gray-600">365-day holding period initiated for restricted securities</p>
                  <p className="text-xs text-gray-500 mt-1">March 22, 2024</p>
                </div>
              </div>
            </div>
          </div>
        )}
      </main>
    </div>
  )
}