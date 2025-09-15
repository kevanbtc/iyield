'use client'

import { Shield, Zap, TrendingUp } from 'lucide-react'
import Image from 'next/image'

export default function Header() {
  return (
    <header className="bg-white/80 dark:bg-slate-900/80 backdrop-blur-sm border-b border-slate-200 dark:border-slate-700">
      <div className="container mx-auto px-4 py-4 flex items-center justify-between">
        <div className="flex items-center space-x-2">
          <div className="relative">
            <div className="w-10 h-10 bg-gradient-to-br from-blue-500 to-purple-600 rounded-xl flex items-center justify-center">
              <TrendingUp className="h-6 w-6 text-white" />
            </div>
            <div className="absolute -top-1 -right-1 w-3 h-3 bg-green-500 rounded-full border-2 border-white dark:border-slate-900"></div>
          </div>
          <div>
            <h1 className="text-xl font-bold bg-gradient-to-r from-blue-600 to-purple-600 bg-clip-text text-transparent">
              iYield Protocol
            </h1>
            <p className="text-xs text-slate-500 dark:text-slate-400">
              Proof-of-CSV™ Insurance RWA
            </p>
          </div>
        </div>
        
        <div className="flex items-center space-x-6">
          <div className="hidden md:flex items-center space-x-4">
            <div className="flex items-center space-x-2 text-sm">
              <Shield className="h-4 w-4 text-green-500" />
              <span className="text-slate-600 dark:text-slate-300">Compliant</span>
            </div>
            <div className="flex items-center space-x-2 text-sm">
              <Zap className="h-4 w-4 text-blue-500" />
              <span className="text-slate-600 dark:text-slate-300">Live Oracle</span>
            </div>
          </div>
          
          <button className="bg-gradient-to-r from-blue-500 to-purple-600 text-white px-4 py-2 rounded-lg font-medium hover:from-blue-600 hover:to-purple-700 transition-all duration-200 shadow-lg hover:shadow-xl">
            Connect Wallet
          </button>
        </div>
      </div>
    </header>
  )
}