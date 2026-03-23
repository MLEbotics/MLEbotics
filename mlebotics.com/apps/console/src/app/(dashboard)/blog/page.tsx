'use client'

import { useEffect, useState } from 'react'
import Link from 'next/link'
import { getBlogPosts, deleteBlogPost, type BlogPost } from '@/lib/firebase'
import { PenLine, Trash2, Eye, EyeOff, Plus } from 'lucide-react'

export default function BlogPage() {
  const [posts, setPosts] = useState<BlogPost[]>([])
  const [loading, setLoading] = useState(true)

  async function load() {
    setLoading(true)
    const data = await getBlogPosts()
    setPosts(data)
    setLoading(false)
  }

  useEffect(() => { load() }, [])

  async function handleDelete(id: string, title: string) {
    if (!confirm(`Delete "${title}"? This cannot be undone.`)) return
    await deleteBlogPost(id)
    setPosts(p => p.filter(x => x.id !== id))
  }

  return (
    <div className="max-w-4xl mx-auto">
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-xl font-bold text-white">Blog Posts</h1>
          <p className="text-sm text-gray-500 mt-0.5">Write and manage posts published to mlebotics.com</p>
        </div>
        <Link
          href="/blog/new"
          className="flex items-center gap-2 rounded-lg bg-cyan-600 px-4 py-2 text-sm font-semibold text-white hover:bg-cyan-500 transition-colors"
        >
          <Plus className="h-4 w-4" />
          New post
        </Link>
      </div>

      {loading ? (
        <div className="text-sm text-gray-500 animate-pulse">Loading posts…</div>
      ) : posts.length === 0 ? (
        <div className="rounded-xl border border-gray-800 bg-gray-900 p-12 text-center">
          <PenLine className="h-8 w-8 text-gray-600 mx-auto mb-4" />
          <p className="text-gray-400 font-medium">No posts yet</p>
          <p className="text-gray-600 text-sm mt-1">Write your first blog post for mlebotics.com</p>
          <Link
            href="/blog/new"
            className="mt-5 inline-flex items-center gap-2 rounded-lg bg-cyan-600 px-4 py-2 text-sm font-semibold text-white hover:bg-cyan-500 transition-colors"
          >
            <Plus className="h-4 w-4" />
            Write first post
          </Link>
        </div>
      ) : (
        <div className="flex flex-col gap-3">
          {posts.map(post => (
            <div
              key={post.id}
              className="flex items-start gap-4 rounded-xl border border-gray-800 bg-gray-900 p-5 hover:border-gray-700 transition-colors"
            >
              <div className="flex-1 min-w-0">
                <div className="flex items-center gap-2 mb-1 flex-wrap">
                  <h2 className="text-base font-semibold text-white truncate">{post.title}</h2>
                  <span className={`flex-shrink-0 text-[10px] font-semibold px-2 py-0.5 rounded-full ${
                    post.published
                      ? 'bg-green-500/10 text-green-400 border border-green-500/20'
                      : 'bg-gray-700 text-gray-400 border border-gray-600'
                  }`}>
                    {post.published ? 'Published' : 'Draft'}
                  </span>
                </div>
                <p className="text-sm text-gray-500 line-clamp-2">{post.excerpt}</p>
                <div className="flex items-center gap-3 mt-2 flex-wrap">
                  <span className="text-xs text-gray-600">By {post.authorName}</span>
                  {post.createdAt && (
                    <span className="text-xs text-gray-600">
                      {new Date((post.createdAt as { seconds: number }).seconds * 1000).toLocaleDateString()}
                    </span>
                  )}
                  {post.tags.slice(0, 3).map(t => (
                    <span key={t} className="text-xs border border-gray-700 rounded px-1.5 py-0.5 text-gray-500">{t}</span>
                  ))}
                </div>
              </div>
              <div className="flex items-center gap-1 flex-shrink-0">
                {post.published ? (
                  <a
                    href={`https://mlebotics.com/blog/read?id=${post.id}`}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="p-2 rounded-lg text-gray-500 hover:text-cyan-400 hover:bg-cyan-400/10 transition-colors"
                    title="View on site"
                  >
                    <Eye className="h-4 w-4" />
                  </a>
                ) : (
                  <span className="p-2 rounded-lg text-gray-700" title="Draft — not visible on site">
                    <EyeOff className="h-4 w-4" />
                  </span>
                )}
                <Link
                  href={`/blog/${post.id}/edit`}
                  className="p-2 rounded-lg text-gray-500 hover:text-white hover:bg-gray-700 transition-colors"
                  title="Edit"
                >
                  <PenLine className="h-4 w-4" />
                </Link>
                <button
                  onClick={() => handleDelete(post.id, post.title)}
                  className="p-2 rounded-lg text-gray-500 hover:text-red-400 hover:bg-red-400/10 transition-colors"
                  title="Delete"
                >
                  <Trash2 className="h-4 w-4" />
                </button>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  )
}
