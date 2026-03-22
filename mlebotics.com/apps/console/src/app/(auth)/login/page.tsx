export default function LoginPage() {
  return (
    <main className="flex min-h-screen items-center justify-center bg-gray-950">
      <div className="w-full max-w-sm rounded-lg border border-gray-800 bg-gray-900 p-8">
        <h1 className="mb-6 text-2xl font-bold text-white">Sign in</h1>
        {/* TODO: Replace with <SignIn /> from @clerk/nextjs */}
        <p className="text-sm text-gray-400">Auth not implemented yet.</p>
        <a
          href="/dashboard"
          className="mt-4 block rounded-md bg-indigo-600 px-4 py-2 text-center text-sm font-medium text-white hover:bg-indigo-500"
        >
          Continue (dev bypass)
        </a>
      </div>
    </main>
  )
}
