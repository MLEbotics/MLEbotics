const sections = [
  {
    title: 'Organization',
    fields: [
      { label: 'Organization Name', placeholder: 'MLEbotics', type: 'text' },
      { label: 'Slug',              placeholder: 'mlebotics',  type: 'text' },
    ],
  },
  {
    title: 'Account',
    fields: [
      { label: 'Display Name', placeholder: 'Your Name',          type: 'text' },
      { label: 'Email',        placeholder: 'you@mlebotics.com',  type: 'email' },
    ],
  },
]

export default function SettingsPage() {
  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-2xl font-bold text-white">Settings</h1>
        <p className="mt-1 text-sm text-gray-400">Manage your organization and account preferences.</p>
      </div>

      {sections.map((section) => (
        <div key={section.title} className="rounded-lg border border-gray-800 bg-gray-900">
          <div className="border-b border-gray-800 px-6 py-4">
            <h2 className="text-sm font-semibold text-white">{section.title}</h2>
          </div>
          <div className="space-y-4 p-6">
            {section.fields.map((field) => (
              <div key={field.label}>
                <label className="mb-1.5 block text-xs font-medium text-gray-400">{field.label}</label>
                <input
                  type={field.type}
                  placeholder={field.placeholder}
                  className="w-full rounded-md border border-gray-700 bg-gray-800 px-3 py-2 text-sm text-white placeholder-gray-600 focus:border-indigo-500 focus:outline-none focus:ring-1 focus:ring-indigo-500"
                />
              </div>
            ))}
          </div>
          <div className="flex justify-end border-t border-gray-800 px-6 py-4">
            <button className="rounded-md bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-500">
              Save Changes
            </button>
          </div>
        </div>
      ))}
    </div>
  )
}
