'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { createBlogPost, updateBlogPost, useAuth, type BlogPost } from '@/lib/firebase'
import { useAuth as useAuthCtx } from '@/lib/auth-context'
import { ArrowLeft, Save, Eye, EyeOff } from 'lucide-react'
import Link from 'next/link'

interface Props {
  post?: BlogPost  // undefined = new post
}

function slugify(str: string) {
  return str.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, '').slice(0, 80)
}

export function BlogEditor({ post }: Props) {
  const router = useRouter()
  const { user } = useAuthCtx()

  const [title, setTitle] = useState(post?.title ?? '')
  const [excerpt, setExcerpt] = useState(post?.excerpt ?? '')
  const [content, setContent] = useState(post?.content ?? '')
  const [tagsInput, setTagsInput] = useState(post?.tags.join(', ') ?? '')
  const [published, setPublished] = useState(post?.published ?? false)
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState('')
  const [saved, setSaved] = useState(false)

  async function handleSave(publish?: boolean) {
    if (!title.trim()) { setError('Title is required'); return }
    if (!content.trim()) { setError('Content is required'); return }
    setError('')
    setSaving(true)
    try {
      const tags = tagsInput.split(',').map(t => t.trim()).filter(Boolean)
      const shouldPublish = publish !== undefined ? publish : published
      const data = {
        title: title.trim(),
        slug: slugify(title),
        excerpt: excerpt.trim() || content.replace(/#+\s/g, '').slice(0, 160) + '…',
        content: content.trim(),
        tags,
        authorName: user?.displayName || user?.email?.split('@')[0] || 'Eddie Chongtham',
        authorEmail: user?.email || 'eddie@mlebotics.com',
        published: shouldPublish,
      }
      if (post) {
        await updateBlogPost(post.id, data)
      } else {
        await createBlogPost(data)
      }
      setSaved(true)
      setTimeout(() => router.push('/blog'), 800)
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : String(e))
    } finally {
      setSaving(false)
    }
  }

  return (
    <div className="max-w-4xl mx-auto">
      {/* Header */}
      <div className="flex items-center gap-4 mb-6">
        <Link href="/blog" className="p-2 rounded-lg text-gray-500 hover:text-white hover:bg-gray-800 transition-colors">
          <ArrowLeft className="h-4 w-4" />
        </Link>
        <div className="flex-1">
          <h1 className="text-lg font-bold text-white">{post ? 'Edit post' : 'New post'}</h1>
          {user && <p className="text-xs text-gray-500 mt-0.5">Posting as {user.displayName || user.email}</p>}
        </div>
        <div className="flex items-center gap-2">
          <button
            onClick={() => setPublished(!published)}
            className={`flex items-center gap-2 rounded-lg border px-3 py-2 text-sm font-medium transition-colors ${
              published
                ? 'border-green-500/30 bg-green-500/10 text-green-400'
                : 'border-gray-700 bg-gray-800 text-gray-400'
            }`}
          >
            {published ? <Eye className="h-3.5 w-3.5" /> : <EyeOff className="h-3.5 w-3.5" />}
            {published ? 'Published' : 'Draft'}
          </button>
          <button
            disabled={saving || saved}
            onClick={() => handleSave()}
            className="flex items-center gap-2 rounded-lg bg-cyan-600 px-4 py-2 text-sm font-semibold text-white hover:bg-cyan-500 transition-colors disabled:opacity-50"
          >
            <Save className="h-3.5 w-3.5" />
            {saved ? 'Saved!' : saving ? 'Saving…' : 'Save'}
          </button>
        </div>
      </div>

      {error && (
        <div className="mb-4 rounded-lg bg-red-500/10 border border-red-500/20 px-4 py-3 text-sm text-red-400">
          {error}
        </div>
      )}

      <div className="flex flex-col gap-4">
        {/* Title */}
        <input
          type="text"
          placeholder="Post title…"
          value={title}
          onChange={e => setTitle(e.target.value)}
          className="rounded-xl border border-gray-700 bg-gray-900 px-5 py-4 text-2xl font-bold text-white placeholder-gray-600 focus:border-cyan-500 focus:outline-none"
        />

        {/* Excerpt */}
        <textarea
          placeholder="Short excerpt (shows on blog index, 1–2 sentences)…"
          value={excerpt}
          onChange={e => setExcerpt(e.target.value)}
          rows={2}
          className="rounded-xl border border-gray-700 bg-gray-900 px-5 py-3 text-sm text-gray-300 placeholder-gray-600 focus:border-cyan-500 focus:outline-none resize-none"
        />

        {/* Tags */}
        <input
          type="text"
          placeholder="Tags (comma-separated): Flutter, Firebase, AI"
          value={tagsInput}
          onChange={e => setTagsInput(e.target.value)}
          className="rounded-xl border border-gray-700 bg-gray-900 px-5 py-3 text-sm text-gray-300 placeholder-gray-600 focus:border-cyan-500 focus:outline-none"
        />

        {/* Content */}
        <div className="rounded-xl border border-gray-700 bg-gray-900 overflow-hidden">
          <div className="border-b border-gray-800 px-5 py-2 flex items-center gap-2">
            <span className="text-xs font-semibold text-gray-500 uppercase tracking-wider">Content — Markdown supported</span>
          </div>
          <textarea
            placeholder={`# Your heading\n\nWrite your post here. Markdown is supported — use **bold**, _italic_, \`code\`, ## headings, and > blockquotes.`}
            value={content}
            onChange={e => setContent(e.target.value)}
            rows={28}
            className="w-full bg-transparent px-5 py-4 text-sm text-gray-200 placeholder-gray-600 focus:outline-none resize-none font-mono leading-relaxed"
          />
        </div>

        {/* Slug preview */}
        {title && (
          <p className="text-xs text-gray-600">
            Slug: <span className="text-gray-500 font-mono">/blog/read?id=…</span>
            {' · '}auto-generated from title
          </p>
        )}

        {/* Bottom action bar */}
        <div className="flex justify-end gap-3 pt-2">
          <Link
            href="/blog"
            className="rounded-lg border border-gray-700 px-4 py-2 text-sm text-gray-400 hover:text-white hover:border-gray-600 transition-colors"
          >
            Cancel
          </Link>
          <button
            onClick={() => handleSave(false)}
            disabled={saving}
            className="rounded-lg border border-gray-700 bg-gray-800 px-4 py-2 text-sm text-gray-300 hover:bg-gray-700 transition-colors disabled:opacity-50"
          >
            Save as draft
          </button>
          <button
            onClick={() => handleSave(true)}
            disabled={saving || saved}
            className="rounded-lg bg-cyan-600 px-6 py-2 text-sm font-semibold text-white hover:bg-cyan-500 transition-colors disabled:opacity-50"
          >
            {saved ? 'Published!' : 'Publish'}
          </button>
        </div>
      </div>
    </div>
  )
}
