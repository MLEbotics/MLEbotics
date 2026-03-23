'use client'

import { useEffect, useState } from 'react'
import { useParams } from 'next/navigation'
import { getBlogPost, type BlogPost } from '@/lib/firebase'
import { BlogEditor } from '@/components/BlogEditor'

export default function EditPostPage() {
  const { id } = useParams<{ id: string }>()
  const [post, setPost] = useState<BlogPost | null>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    getBlogPost(id).then(p => { setPost(p); setLoading(false) })
  }, [id])

  if (loading) return <div className="text-sm text-gray-500 animate-pulse">Loading post…</div>
  if (!post) return <div className="text-sm text-red-400">Post not found.</div>

  return <BlogEditor post={post} />
}
