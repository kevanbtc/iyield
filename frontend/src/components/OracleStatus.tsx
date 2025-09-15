'use client'

import { CheckCircle, Clock, AlertTriangle, ExternalLink } from 'lucide-react'

interface OracleStatusProps {
  detailed?: boolean
}

export default function OracleStatus({ detailed = false }: OracleStatusProps) {
  // Mock data - in real implementation, this would come from smart contracts
  const oracleData = {
    status: 'active',
    lastUpdate: '2 minutes ago',
    attestors: [
      { name: 'Trustee Alpha', address: '0x1234...5678', status: 'active', lastSeen: '1 min ago' },
      { name: 'Guardian Beta', address: '0x9876...5432', status: 'active', lastSeen: '2 min ago' },
      { name: 'Custodian Gamma', address: '0xabcd...efgh', status: 'active', lastSeen: '1 min ago' }
    ],
    currentValuation: '$24,687,432',
    merkleRoot: '0x7d865e959b2466918c9863afca942d0fb89d7c9ac0c99bafc3749504ded97730',
    ipfsHash: 'QmYjZjgHCjZjU8gNzZjE3CjZjU8gN1ZjE3CjZjU8gN2ZjE3C'
  }

  const carriers = [
    { name: 'MetLife', rating: 'AA+', csvValue: '$8.2M', status: 'active' },
    { name: 'Prudential', rating: 'AA+', csvValue: '$7.1M', status: 'active' },
    { name: 'Northwestern Mutual', rating: 'AAA', csvValue: '$6.8M', status: 'active' },
    { name: 'New York Life', rating: 'AAA', csvValue: '$2.6M', status: 'active' }
  ]

  return (
    <div className="bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 p-6">
      <div className="flex items-center justify-between mb-6">
        <h3 className="text-lg font-semibold text-slate-900 dark:text-white flex items-center space-x-2">
          <div className="w-3 h-3 bg-green-500 rounded-full animate-pulse"></div>
          <span>Proof-of-CSV™ Oracle</span>
        </h3>
        <div className="text-sm text-slate-500 dark:text-slate-400">
          Updated {oracleData.lastUpdate}
        </div>
      </div>

      {/* Oracle Status Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mb-6">
        <div className="bg-green-50 dark:bg-green-900/20 border border-green-200 dark:border-green-800 rounded-lg p-4">
          <div className="flex items-center space-x-2 mb-2">
            <CheckCircle className="h-5 w-5 text-green-600 dark:text-green-400" />
            <span className="font-medium text-green-900 dark:text-green-100">Live Attestation</span>
          </div>
          <p className="text-sm text-green-700 dark:text-green-300">
            All {oracleData.attestors.length} attestors reporting
          </p>
        </div>

        <div className="bg-blue-50 dark:bg-blue-900/20 border border-blue-200 dark:border-blue-800 rounded-lg p-4">
          <div className="flex items-center space-x-2 mb-2">
            <Clock className="h-5 w-5 text-blue-600 dark:text-blue-400" />
            <span className="font-medium text-blue-900 dark:text-blue-100">Fresh Data</span>
          </div>
          <p className="text-sm text-blue-700 dark:text-blue-300">
            Within 7-day freshness window
          </p>
        </div>
      </div>

      {/* Attestors */}
      <div className="mb-6">
        <h4 className="font-medium text-slate-900 dark:text-white mb-3">Active Attestors</h4>
        <div className="space-y-2">
          {oracleData.attestors.map((attestor, index) => (
            <div key={index} className="flex items-center justify-between p-3 bg-slate-50 dark:bg-slate-700/50 rounded-lg">
              <div className="flex items-center space-x-3">
                <div className="w-2 h-2 bg-green-500 rounded-full"></div>
                <div>
                  <p className="font-medium text-slate-900 dark:text-white text-sm">{attestor.name}</p>
                  <p className="text-xs text-slate-500 dark:text-slate-400">{attestor.address}</p>
                </div>
              </div>
              <div className="text-right">
                <p className="text-sm text-slate-600 dark:text-slate-300">{attestor.lastSeen}</p>
                <p className="text-xs text-green-600 dark:text-green-400">Active</p>
              </div>
            </div>
          ))}
        </div>
      </div>

      {detailed && (
        <>
          {/* Carrier Breakdown */}
          <div className="mb-6">
            <h4 className="font-medium text-slate-900 dark:text-white mb-3">Insurance Carriers</h4>
            <div className="space-y-2">
              {carriers.map((carrier, index) => (
                <div key={index} className="flex items-center justify-between p-3 bg-slate-50 dark:bg-slate-700/50 rounded-lg">
                  <div className="flex items-center space-x-3">
                    <div className="w-2 h-2 bg-green-500 rounded-full"></div>
                    <div>
                      <p className="font-medium text-slate-900 dark:text-white text-sm">{carrier.name}</p>
                      <p className="text-xs text-slate-500 dark:text-slate-400">Rating: {carrier.rating}</p>
                    </div>
                  </div>
                  <div className="text-right">
                    <p className="text-sm font-medium text-slate-900 dark:text-white">{carrier.csvValue}</p>
                    <p className="text-xs text-green-600 dark:text-green-400">Active</p>
                  </div>
                </div>
              ))}
            </div>
          </div>

          {/* Technical Details */}
          <div className="space-y-4 pt-4 border-t border-slate-200 dark:border-slate-700">
            <div>
              <label className="text-sm font-medium text-slate-500 dark:text-slate-400">Current Valuation</label>
              <p className="text-lg font-semibold text-slate-900 dark:text-white">{oracleData.currentValuation}</p>
            </div>
            
            <div>
              <label className="text-sm font-medium text-slate-500 dark:text-slate-400">Merkle Root</label>
              <div className="flex items-center space-x-2">
                <p className="text-sm font-mono text-slate-700 dark:text-slate-300 break-all">
                  {oracleData.merkleRoot}
                </p>
                <ExternalLink className="h-4 w-4 text-slate-400 hover:text-blue-500 cursor-pointer flex-shrink-0" />
              </div>
            </div>
            
            <div>
              <label className="text-sm font-medium text-slate-500 dark:text-slate-400">IPFS Attestation</label>
              <div className="flex items-center space-x-2">
                <p className="text-sm font-mono text-slate-700 dark:text-slate-300 break-all">
                  {oracleData.ipfsHash}
                </p>
                <ExternalLink className="h-4 w-4 text-slate-400 hover:text-blue-500 cursor-pointer flex-shrink-0" />
              </div>
            </div>
          </div>
        </>
      )}
    </div>
  )
}