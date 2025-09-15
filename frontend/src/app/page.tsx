import Header from '@/components/Header'
import Dashboard from '@/components/Dashboard'
import Footer from '@/components/Footer'

export default function Home() {
  return (
    <div className="min-h-screen bg-gradient-to-br from-slate-50 to-slate-100 dark:from-slate-900 dark:to-slate-800">
      <Header />
      <main className="container mx-auto px-4 py-8">
        <Dashboard />
      </main>
      <Footer />
    </div>
  )
}
