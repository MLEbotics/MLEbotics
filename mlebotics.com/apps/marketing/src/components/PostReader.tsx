import { useEffect, useState } from 'react'
import {
  getPostById, getComments, addComment, getReactions, addReaction,
  REACTION_EMOJIS, type BlogPostPublic, type BlogComment, type ReactionCounts, type ReactionEmoji,
} from '../lib/firebase'

function formatDate(post: BlogPostPublic) {
  if (!post.createdAt) return ''
  return new Date(post.createdAt.seconds * 1000).toLocaleDateString('en-US', {
    year: 'numeric', month: 'long', day: 'numeric',
  })
}

/** Very light Markdown → HTML for rendering blog content.
 *  Handles: headings, bold, italic, code blocks, inline code, line breaks.
 *  For production replace with a proper Markdown library (marked, micromark, etc.)
 */
function simpleMarkdown(md: string): string {
  let html = md
    // fenced code blocks
    .replace(/```[\w]*\n([\s\S]*?)```/g, '<pre><code>$1</code></pre>')
    // headings
    .replace(/^### (.+)$/gm, '<h3>$1</h3>')
    .replace(/^## (.+)$/gm, '<h2>$1</h2>')
    .replace(/^# (.+)$/gm, '<h1>$1</h1>')
    // bold + italic
    .replace(/\*\*\*(.+?)\*\*\*/g, '<strong><em>$1</em></strong>')
    .replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>')
    .replace(/\*(.+?)\*/g, '<em>$1</em>')
    // inline code
    .replace(/`([^`]+)`/g, '<code>$1</code>')
    // horizontal rule
    .replace(/^---$/gm, '<hr />')
    // line breaks — double newline = paragraph
    .split(/\n{2,}/)
    .map(block => {
      if (block.startsWith('<h') || block.startsWith('<pre') || block.startsWith('<hr')) return block
      return `<p>${block.replace(/\n/g, '<br/>')}</p>`
    })
    .join('\n')
  return html
}

const REACTION_LABELS: Record<string, string> = {
  '👍': 'Like',
  '❤️': 'Love',
  '😂': 'Haha',
  '🔥': 'Fire',
  '🤯': 'Mind Blown',
  '👏': 'Clap',
}

function ReactionsBar({ postId }: { postId: string }) {
  const [counts, setCounts] = useState<ReactionCounts | null>(null)
  const [reacted, setReacted] = useState<Set<ReactionEmoji>>(new Set())
  const [animating, setAnimating] = useState<ReactionEmoji | null>(null)

  useEffect(() => {
    getReactions(postId).then(setCounts)
    // Restore already-reacted emojis from localStorage
    try {
      const stored = JSON.parse(localStorage.getItem(`reactions:${postId}`) ?? '[]')
      setReacted(new Set(stored))
    } catch { /* ignore */ }
  }, [postId])

  async function handleReact(emoji: ReactionEmoji) {
    if (reacted.has(emoji)) return
    // Optimistic update
    setCounts(prev => prev ? { ...prev, [emoji]: (prev[emoji] ?? 0) + 1 } : prev)
    const next = new Set([...reacted, emoji])
    setReacted(next)
    setAnimating(emoji)
    setTimeout(() => setAnimating(null), 600)
    // Persist to localStorage
    localStorage.setItem(`reactions:${postId}`, JSON.stringify([...next]))
    // Write to Firestore
    try { await addReaction(postId, emoji) } catch { /* best-effort */ }
  }

  if (!counts) return null

  return (
    <div style={{
      display: 'flex', gap: '.6rem', flexWrap: 'wrap',
      margin: '2rem 0', padding: '1.25rem 1.5rem',
      background: 'rgba(255,255,255,.025)', border: '1px solid var(--border)',
      borderRadius: '12px', alignItems: 'center',
    }}>
      <span style={{ fontSize: '.75rem', color: 'var(--muted)', marginRight: '.25rem' }}>React:</span>
      {REACTION_EMOJIS.map(emoji => {
        const count = counts[emoji] ?? 0
        const done = reacted.has(emoji)
        const pop = animating === emoji
        return (
          <button
            key={emoji}
            onClick={() => handleReact(emoji)}
            title={REACTION_LABELS[emoji]}
            style={{
              display: 'inline-flex', alignItems: 'center', gap: '.35rem',
              background: done ? 'rgba(0,212,255,.1)' : 'rgba(255,255,255,.04)',
              border: `1px solid ${done ? 'rgba(0,212,255,.35)' : 'var(--border)'}`,
              borderRadius: '99px', padding: '.3rem .8rem',
              cursor: done ? 'default' : 'pointer',
              fontSize: '1rem', transition: 'transform .15s, background .2s',
              transform: pop ? 'scale(1.35)' : 'scale(1)',
              userSelect: 'none',
            }}
          >
            <span>{emoji}</span>
            {count > 0 && (
              <span style={{ fontSize: '.75rem', fontWeight: 600, color: done ? 'var(--cyan)' : '#94a3b8' }}>
                {count}
              </span>
            )}
          </button>
        )
      })}
    </div>
  )
}

function CommentsSection({ postId }: { postId: string }) {
  const [comments, setComments] = useState<BlogComment[]>([])
  const [name, setName] = useState('')
  const [content, setContent] = useState('')
  const [submitting, setSubmitting] = useState(false)
  const [submitted, setSubmitted] = useState(false)
  const [submitError, setSubmitError] = useState('')

  useEffect(() => {
    getComments(postId).then(setComments)
  }, [postId])

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    if (!name.trim() || !content.trim()) return
    setSubmitting(true)
    setSubmitError('')
    try {
      await addComment(postId, name, content)
      setSubmitted(true)
      setName('')
      setContent('')
      // Optimistically add to local list
      setComments(prev => [...prev, {
        id: Date.now().toString(),
        postId,
        name: name.trim(),
        content: content.trim(),
        createdAt: { seconds: Math.floor(Date.now() / 1000) },
      }])
    } catch {
      setSubmitError('Failed to post comment. Please try again.')
    } finally {
      setSubmitting(false)
    }
  }

  const inputStyle: React.CSSProperties = {
    width: '100%', background: 'rgba(255,255,255,.04)', border: '1px solid var(--border)',
    borderRadius: '8px', padding: '.65rem .9rem', color: '#e2e8f0',
    fontSize: '.875rem', outline: 'none', boxSizing: 'border-box',
  }

  return (
    <div style={{ marginTop: '3.5rem' }}>
      <h3 style={{ fontSize: '1.1rem', fontWeight: 700, color: '#fff', marginBottom: '1.5rem' }}>
        Comments {comments.length > 0 && <span style={{ color: 'var(--muted)', fontWeight: 400 }}>({comments.length})</span>}
      </h3>

      {/* Existing comments */}
      {comments.length > 0 && (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem', marginBottom: '2rem' }}>
          {comments.map(c => (
            <div key={c.id} style={{
              background: 'rgba(255,255,255,.03)', border: '1px solid var(--border)',
              borderRadius: '10px', padding: '1rem 1.25rem',
            }}>
              <div style={{ display: 'flex', gap: '.6rem', alignItems: 'center', marginBottom: '.5rem' }}>
                <span style={{ fontWeight: 600, fontSize: '.875rem', color: '#e2e8f0' }}>{c.name}</span>
                {c.createdAt && (
                  <span style={{ fontSize: '.75rem', color: 'var(--muted)' }}>
                    {new Date(c.createdAt.seconds * 1000).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })}
                  </span>
                )}
              </div>
              <p style={{ fontSize: '.875rem', color: '#94a3b8', lineHeight: 1.65, margin: 0, whiteSpace: 'pre-wrap' }}>{c.content}</p>
            </div>
          ))}
        </div>
      )}

      {/* Comment form */}
      <div style={{
        background: 'rgba(255,255,255,.02)', border: '1px solid var(--border)',
        borderRadius: '12px', padding: '1.5rem',
      }}>
        <p style={{ fontSize: '.875rem', color: 'var(--muted)', marginBottom: '1rem', lineHeight: 1.6 }}>
          Leave a comment — no account needed.
        </p>

        {submitted ? (
          <p style={{ color: '#4ade80', fontSize: '.875rem' }}>Comment posted — thanks!</p>
        ) : (
          <form onSubmit={handleSubmit} style={{ display: 'flex', flexDirection: 'column', gap: '.75rem' }}>
            <input
              type="text" placeholder="Your name *" value={name} required maxLength={80}
              onChange={e => setName(e.target.value)} style={inputStyle}
            />
            <textarea
              placeholder="Your comment *" value={content} required maxLength={2000} rows={4}
              onChange={e => setContent(e.target.value)}
              style={{ ...inputStyle, resize: 'vertical', fontFamily: 'inherit' }}
            />
            {submitError && <p style={{ color: '#f87171', fontSize: '.8rem', margin: 0 }}>{submitError}</p>}
            <button
              type="submit" disabled={submitting || !name.trim() || !content.trim()}
              style={{
                alignSelf: 'flex-start', background: 'var(--cyan)', color: '#000',
                border: 'none', borderRadius: '8px', padding: '.55rem 1.4rem',
                fontWeight: 700, fontSize: '.875rem', cursor: submitting ? 'not-allowed' : 'pointer',
                opacity: submitting ? .6 : 1,
              }}
            >
              {submitting ? 'Posting…' : 'Post Comment'}
            </button>
          </form>
        )}
      </div>
    </div>
  )
}

export default function PostReader() {
  const [post, setPost] = useState<BlogPostPublic | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [postId, setPostId] = useState('')

  useEffect(() => {
    const id = new URLSearchParams(window.location.search).get('id')
    if (!id) { setError('No post ID specified.'); setLoading(false); return }
    setPostId(id)
    getPostById(id)
      .then(p => {
        if (!p) { setError('Post not found.'); setLoading(false); return }
        setPost(p)
        setLoading(false)
        document.title = `${p.title} — MLEbotics Blog`
      })
      .catch(() => { setError('Failed to load post.'); setLoading(false) })
  }, [])

  if (loading) return (
    <div style={{ color: 'var(--muted)', padding: '4rem 0', textAlign: 'center' }}>Loading…</div>
  )

  if (error) return (
    <div style={{ color: '#f87171', padding: '4rem 0', textAlign: 'center' }}>
      {error} <a href="/blog" style={{ color: 'var(--cyan)', marginLeft: '.5rem' }}>← Back to Blog</a>
    </div>
  )

  if (!post) return null

  const html = simpleMarkdown(post.content)

  return (
    <article style={{ maxWidth: 740, margin: '0 auto' }}>
      {/* breadcrumb */}
      <div style={{ marginBottom: '2rem', fontSize: '.8rem', color: 'var(--muted)' }}>
        <a href="/blog" style={{ color: 'var(--cyan)', textDecoration: 'none' }}>Blog</a>
        <span style={{ margin: '0 .5rem' }}>›</span>
        <span>{post.title}</span>
      </div>

      {/* header */}
      <div style={{ marginBottom: '2.5rem' }}>
        <div style={{ display: 'flex', gap: '.75rem', alignItems: 'center', marginBottom: '1rem', flexWrap: 'wrap' }}>
          <span style={{ fontSize: '.8rem', color: 'var(--muted)' }}>{formatDate(post)}</span>
          <span style={{ color: 'var(--muted)', fontSize: '.7rem' }}>·</span>
          <span style={{ fontSize: '.8rem', fontWeight: 600, color: 'var(--cyan)' }}>{post.authorName}</span>
        </div>
        <h1 style={{ fontSize: 'clamp(1.75rem, 4vw, 2.5rem)', fontWeight: 700, color: '#fff', lineHeight: 1.25, marginBottom: '1rem' }}>
          {post.title}
        </h1>
        <p style={{ fontSize: '1rem', color: '#94a3b8', lineHeight: 1.7 }}>{post.excerpt}</p>
        <div style={{ display: 'flex', gap: '.4rem', flexWrap: 'wrap', marginTop: '1rem' }}>
          {post.tags.map(t => (
            <span key={t} style={{
              fontSize: '.7rem', fontWeight: 600, padding: '.2rem .6rem', borderRadius: '99px',
              background: 'rgba(0,212,255,.06)', border: '1px solid rgba(0,212,255,.15)', color: 'var(--cyan)',
            }}>
              {t}
            </span>
          ))}
        </div>
      </div>

      <hr style={{ border: 'none', borderTop: '1px solid var(--border)', marginBottom: '2.5rem' }} />

      {/* content */}
      <div
        style={{ color: '#cbd5e1', lineHeight: 1.85, fontSize: '1rem' }}
        className="post-body"
        dangerouslySetInnerHTML={{ __html: html }}
      />

      {/* Reactions */}
      {postId && <ReactionsBar postId={postId} />}

      {/* Comments */}
      {postId && <CommentsSection postId={postId} />}

      <div style={{ marginTop: '3rem', paddingTop: '2rem', borderTop: '1px solid var(--border)' }}>
        <a href="/blog" style={{ color: 'var(--cyan)', textDecoration: 'none', fontSize: '.875rem' }}>
          ← Back to Blog
        </a>
      </div>
    </article>
  )
}
