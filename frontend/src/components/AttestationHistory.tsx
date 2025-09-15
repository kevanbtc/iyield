'use client'

import { Clock, CheckCircle, AlertCircle, ExternalLink } from 'lucide-react'

export default function AttestationHistory() {
  // Mock data - in real implementation, this would come from oracle contract events
  const attestations = [
    {
      timestamp: '2024-09-15T05:32:15Z',
      merkleRoot: '0x7d865e959b2466918c9863afca942d0fb89d7c9ac0c99bafc3749504ded97730',
      csvValue: 24687432,
      attestors: ['Trustee Alpha', 'Guardian Beta', 'Custodian Gamma'],
      ipfsHash: 'QmYjZjgHCjZjU8gNzZjE3CjZjU8gN1ZjE3CjZjU8gN2ZjE3C',
      status: 'confirmed'
    },
    {
      timestamp: '2024-09-14T05:28:42Z',
      merkleRoot: '0x9f432a1b8c7e5d6f2a9b8c7e5d6f2a9b8c7e5d6f2a9b8c7e5d6f2a9b8c7e5d6f',
      csvValue: 24532108,
      attestors: ['Trustee Alpha', 'Guardian Beta'],
      ipfsHash: 'QmXbYcZdEfGhIjKlMnOpQrStUvWxYzAbCdEfGhIjKlMnOpQr',
      status: 'confirmed'
    },
    {
      timestamp: '2024-09-13T05:25:18Z',
      merkleRoot: '0x2a8b9c7e5d6f2a9b8c7e5d6f2a9b8c7e5d6f2a9b8c7e5d6f2a9b8c7e5d6f2a9',
      csvValue: 24398765,
      attestors: ['Trustee Alpha', 'Guardian Beta', 'Custodian Gamma'],
      ipfsHash: 'QmAbCdEfGhIjKlMnOpQrStUvWxYzAbCdEfGhIjKlMnOpQr',
      status: 'confirmed'
    },
    {
      timestamp: '2024-09-12T05:21:33Z',
      merkleRoot: '0x5c8b9a7e6d5f3a2b1c0e9d8f7a6b5c4d3e2f1a0b9c8e7d6f5a4b3c2d1e0f9a8',
      csvValue: 24287543,
      attestors: ['Trustee Alpha', 'Guardian Beta'],
      ipfsHash: 'QmZaBcDeFgHiJkLmNoPqRsTuVwXyZaBcDeFgHiJkLmNoPqR',
      status: 'confirmed'
    },
    {
      timestamp: '2024-09-11T05:18:07Z',
      merkleRoot: '0x8f9e8d7c6b5a4e9f8e7d6c5b4a3f8e9d8c7b6a5e4f9e8d7c6b5a4e9f8e7d6c5',
      csvValue: 24156219,
      attestors: ['Trustee Alpha', 'Guardian Beta', 'Custodian Gamma'],
      ipfsHash: 'QmPqRsTuVwXyZaBcDeFgHiJkLmNoPqRsTuVwXyZaBcDe',
      status: 'confirmed'
    }
  ]

  const formatTimestamp = (timestamp: string) => {
    const date = new Date(timestamp)
    return {
      date: date.toLocaleDateString(),
      time: date.toLocaleTimeString()
    }
  }

  const formatCurrency = (amount: number) => {
    return new Intl.NumberFormat('en-US', { 
      style: 'currency', 
      currency: 'USD',
      minimumFractionDigits: 0,
      maximumFractionDigits: 0
    }).format(amount)
  }

  const truncateHash = (hash: string, length: number = 12) => {
    return `${hash.substring(0, length)}...${hash.substring(hash.length - 8)}`
  }

  return (
    <div className="bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 p-6">
      <div className="flex items-center justify-between mb-6">
        <h3 className="text-lg font-semibold text-slate-900 dark:text-white flex items-center space-x-2">
          <Clock className="h-5 w-5 text-blue-500" />
          <span>Proof-of-CSV™ Attestation History</span>
        </h3>
        <div className="text-sm text-slate-500 dark:text-slate-400">
          Last 5 attestations
        </div>
      </div>

      <div className="space-y-4">
        {attestations.map((attestation, index) => {
          const timeData = formatTimestamp(attestation.timestamp)
          
          return (
            <div key={index} className="border border-slate-200 dark:border-slate-700 rounded-lg p-4 hover:bg-slate-50 dark:hover:bg-slate-700/30 transition-colors duration-200">
              <div className="flex items-start justify-between mb-3">
                <div className="flex items-center space-x-3">
                  <div className="w-10 h-10 bg-green-100 dark:bg-green-900/30 rounded-lg flex items-center justify-center">
                    <CheckCircle className="h-5 w-5 text-green-600 dark:text-green-400" />
                  </div>
                  <div>
                    <div className="flex items-center space-x-2">
                      <span className="font-medium text-slate-900 dark:text-white">
                        Attestation #{attestations.length - index}
                      </span>
                      <span className="px-2 py-1 bg-green-100 dark:bg-green-900/30 text-green-800 dark:text-green-300 text-xs rounded-full">
                        Confirmed
                      </span>
                    </div>
                    <div className="text-sm text-slate-500 dark:text-slate-400 mt-1">
                      {timeData.date} at {timeData.time}
                    </div>
                  </div>
                </div>
                <div className="text-right">
                  <div className="font-semibold text-slate-900 dark:text-white">
                    {formatCurrency(attestation.csvValue)}
                  </div>
                  <div className="text-sm text-slate-500 dark:text-slate-400">
                    Total CSV Value
                  </div>
                </div>
              </div>

              {/* Attestor badges */}
              <div className="flex items-center space-x-2 mb-3">
                <span className="text-sm text-slate-500 dark:text-slate-400">Attestors:</span>
                {attestation.attestors.map((attestor, idx) => (
                  <span key={idx} className="px-2 py-1 bg-blue-100 dark:bg-blue-900/30 text-blue-800 dark:text-blue-300 text-xs rounded-full">
                    {attestor}
                  </span>
                ))}
              </div>

              {/* Technical details */}
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4 text-sm">
                <div>
                  <label className="text-slate-500 dark:text-slate-400 block mb-1">Merkle Root</label>
                  <div className="flex items-center space-x-2">
                    <span className="font-mono text-slate-700 dark:text-slate-300">
                      {truncateHash(attestation.merkleRoot)}
                    </span>
                    <ExternalLink className="h-4 w-4 text-slate-400 hover:text-blue-500 cursor-pointer" />
                  </div>
                </div>
                <div>
                  <label className="text-slate-500 dark:text-slate-400 block mb-1">IPFS Hash</label>
                  <div className="flex items-center space-x-2">
                    <span className="font-mono text-slate-700 dark:text-slate-300">
                      {truncateHash(attestation.ipfsHash)}
                    </span>
                    <ExternalLink className="h-4 w-4 text-slate-400 hover:text-blue-500 cursor-pointer" />
                  </div>
                </div>
              </div>

              {/* Value change indicator */}
              {index < attestations.length - 1 && (
                <div className="mt-3 pt-3 border-t border-slate-200 dark:border-slate-700">
                  <div className="flex items-center space-x-2 text-sm">
                    <span className="text-slate-500 dark:text-slate-400">Change from previous:</span>
                    {attestation.csvValue > attestations[index + 1].csvValue ? (
                      <span className="text-green-600 dark:text-green-400 flex items-center space-x-1">
                        <span>↑</span>
                        <span>+{formatCurrency(attestation.csvValue - attestations[index + 1].csvValue)}</span>
                      </span>
                    ) : (
                      <span className="text-red-600 dark:text-red-400 flex items-center space-x-1">
                        <span>↓</span>
                        <span>{formatCurrency(attestation.csvValue - attestations[index + 1].csvValue)}</span>
                      </span>
                    )}
                  </div>
                </div>
              )}
            </div>
          )
        })}
      </div>

      {/* Summary stats */}
      <div className="mt-6 pt-4 border-t border-slate-200 dark:border-slate-700">
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4 text-center">
          <div>
            <div className="text-lg font-semibold text-slate-900 dark:text-white">
              {attestations.length}
            </div>
            <div className="text-sm text-slate-500 dark:text-slate-400">
              Recent Attestations
            </div>
          </div>
          <div>
            <div className="text-lg font-semibold text-green-600 dark:text-green-400">
              100%
            </div>
            <div className="text-sm text-slate-500 dark:text-slate-400">
              Confirmation Rate
            </div>
          </div>
          <div>
            <div className="text-lg font-semibold text-blue-600 dark:text-blue-400">
              ~24h
            </div>
            <div className="text-sm text-slate-500 dark:text-slate-400">
              Avg. Frequency
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}