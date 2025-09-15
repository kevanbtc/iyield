export default function Footer() {
  return (
    <footer className="bg-white/60 dark:bg-slate-900/60 backdrop-blur-sm border-t border-slate-200 dark:border-slate-700 py-8 mt-16">
      <div className="container mx-auto px-4">
        <div className="grid grid-cols-1 md:grid-cols-4 gap-8">
          <div className="space-y-4">
            <h3 className="font-semibold text-slate-900 dark:text-white">iYield Protocol</h3>
            <p className="text-sm text-slate-600 dark:text-slate-400">
              Tokenized insurance cash surrender values with on-chain compliance and proof-of-attestation.
            </p>
            <div className="flex space-x-2">
              <div className="w-2 h-2 bg-green-500 rounded-full"></div>
              <span className="text-xs text-slate-500">Oracle Live</span>
            </div>
          </div>
          
          <div>
            <h4 className="font-medium text-slate-900 dark:text-white mb-4">Protocol</h4>
            <ul className="space-y-2 text-sm text-slate-600 dark:text-slate-400">
              <li><a href="#" className="hover:text-blue-600 dark:hover:text-blue-400">ERC-RWA:CSV Standard</a></li>
              <li><a href="#" className="hover:text-blue-600 dark:hover:text-blue-400">Proof-of-CSV™ Oracle</a></li>
              <li><a href="#" className="hover:text-blue-600 dark:hover:text-blue-400">Compliance Registry</a></li>
              <li><a href="#" className="hover:text-blue-600 dark:hover:text-blue-400">Documentation</a></li>
            </ul>
          </div>
          
          <div>
            <h4 className="font-medium text-slate-900 dark:text-white mb-4">Products</h4>
            <ul className="space-y-2 text-sm text-slate-600 dark:text-slate-400">
              <li><a href="#" className="hover:text-blue-600 dark:hover:text-blue-400">CSV Vault</a></li>
              <li><a href="#" className="hover:text-blue-600 dark:hover:text-blue-400">Liquidity Pool</a></li>
              <li><a href="#" className="hover:text-blue-600 dark:hover:text-blue-400">Senior Tranche</a></li>
              <li><a href="#" className="hover:text-blue-600 dark:hover:text-blue-400">Junior Tranche</a></li>
            </ul>
          </div>
          
          <div>
            <h4 className="font-medium text-slate-900 dark:text-white mb-4">Resources</h4>
            <ul className="space-y-2 text-sm text-slate-600 dark:text-slate-400">
              <li><a href="#" className="hover:text-blue-600 dark:hover:text-blue-400">Whitepaper</a></li>
              <li><a href="#" className="hover:text-blue-600 dark:hover:text-blue-400">Audit Reports</a></li>
              <li><a href="#" className="hover:text-blue-600 dark:hover:text-blue-400">Risk Framework</a></li>
              <li><a href="#" className="hover:text-blue-600 dark:hover:text-blue-400">Governance</a></li>
            </ul>
          </div>
        </div>
        
        <div className="border-t border-slate-200 dark:border-slate-700 mt-8 pt-8 flex flex-col md:flex-row justify-between items-center">
          <div className="text-sm text-slate-500 dark:text-slate-400">
            © 2024 iYield Protocol. All rights reserved.
          </div>
          <div className="flex items-center space-x-4 mt-4 md:mt-0">
            <span className="text-xs text-slate-400">Patent Pending</span>
            <span className="text-xs text-slate-400">•</span>
            <span className="text-xs text-slate-400">ERC-RWA:CSV™</span>
          </div>
        </div>
      </div>
    </footer>
  )
}