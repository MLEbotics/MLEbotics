import { initializeApp, getApps } from 'firebase/app'
import {
  getFirestore,
  enableIndexedDbPersistence,
  collection,
  addDoc,
  updateDoc,
  deleteDoc,
  doc,
  getDocs,
  getDoc,
  query,
  orderBy,
  limit,
  onSnapshot,
  serverTimestamp,
  type Timestamp,
} from 'firebase/firestore'
import {
  getAuth,
  GoogleAuthProvider,
  OAuthProvider,
  signInWithPopup,
  signInWithEmailAndPassword,
  createUserWithEmailAndPassword,
  signOut as firebaseSignOut,
  onAuthStateChanged,
  type User,
} from 'firebase/auth'

const firebaseConfig = {
  apiKey: 'AIzaSyDTJWhkRNMa5lOSdwxGLUGrpvWXrLuljfc', // pragma: allowlist secret
  authDomain: 'running-companion-a935f.firebaseapp.com',
  projectId: 'running-companion-a935f',
  storageBucket: 'running-companion-a935f.firebasestorage.app',
  messagingSenderId: '618174257557',
  appId: '1:618174257557:web:29ca5df050bd6daae9be9c',
}

const app = getApps().length === 0 ? initializeApp(firebaseConfig) : getApps()[0]
const db = getFirestore(app)

// Enable offline persistence (IndexedDB) — only once, ignore if already enabled
if (typeof window !== 'undefined') {
  enableIndexedDbPersistence(db).catch(() => {
    // Already enabled or multi-tab not supported — safe to ignore
  })
}

export interface ChatMessage {
  id: string
  text: string
  from: 'system' | 'user'
  name?: string
  createdAt: Timestamp | null
}

const CHAT_COLLECTION = 'community_chat'

export function subscribeToChatMessages(
  onMessages: (msgs: ChatMessage[]) => void,
  messageLimit = 60,
) {
  const q = query(
    collection(db, CHAT_COLLECTION),
    orderBy('createdAt', 'asc'),
    limit(messageLimit),
  )
  return onSnapshot(q, snapshot => {
    const msgs: ChatMessage[] = snapshot.docs.map(doc => ({
      id: doc.id,
      ...(doc.data({ serverTimestamps: 'estimate' }) as Omit<ChatMessage, 'id'>),
    }))
    onMessages(msgs)
  })
}

export async function sendChatMessage(text: string, name = 'Anonymous') {
  await addDoc(collection(db, CHAT_COLLECTION), {
    text,
    from: 'user' as const,
    name,
    createdAt: serverTimestamp(),
  })
}

// ── Auth ──────────────────────────────────────────────────────────────────────

export const auth = getAuth(app)

/** Emails allowed to access the console. Add more here or move to Firestore. */
const AUTHORIZED_EMAILS = ['eddie@mlebotics.com']

export function isAuthorized(user: User | null): boolean {
  if (!user?.email) return false
  return AUTHORIZED_EMAILS.includes(user.email.toLowerCase())
}

export function watchAuthState(cb: (user: User | null) => void) {
  return onAuthStateChanged(auth, cb)
}

export async function signInWithGoogle() {
  const provider = new GoogleAuthProvider()
  return signInWithPopup(auth, provider)
}

export async function signInWithMicrosoft() {
  const provider = new OAuthProvider('microsoft.com')
  provider.setCustomParameters({ prompt: 'select_account' })
  return signInWithPopup(auth, provider)
}

export async function signInWithApple() {
  const provider = new OAuthProvider('apple.com')
  provider.addScope('email')
  provider.addScope('name')
  return signInWithPopup(auth, provider)
}

export async function signInWithEmail(email: string, password: string) {
  return signInWithEmailAndPassword(auth, email, password)
}

export async function registerWithEmail(email: string, password: string) {
  return createUserWithEmailAndPassword(auth, email, password)
}

export async function signOut() {
  return firebaseSignOut(auth)
}

export type { User }

// ── Blog ──────────────────────────────────────────────────────────────────────

export interface BlogPost {
  id: string
  title: string
  slug: string
  excerpt: string
  content: string
  tags: string[]
  authorName: string
  authorEmail: string
  published: boolean
  createdAt: Timestamp | null
  updatedAt: Timestamp | null
}

const BLOG_COLLECTION = 'blog_posts'

export async function createBlogPost(
  data: Omit<BlogPost, 'id' | 'createdAt' | 'updatedAt'>,
): Promise<string> {
  const ref = await addDoc(collection(db, BLOG_COLLECTION), {
    ...data,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  })
  return ref.id
}

export async function updateBlogPost(
  id: string,
  data: Partial<Omit<BlogPost, 'id' | 'createdAt'>>,
): Promise<void> {
  await updateDoc(doc(db, BLOG_COLLECTION, id), {
    ...data,
    updatedAt: serverTimestamp(),
  })
}

export async function deleteBlogPost(id: string): Promise<void> {
  await deleteDoc(doc(db, BLOG_COLLECTION, id))
}

export async function getBlogPosts(): Promise<BlogPost[]> {
  const q = query(collection(db, BLOG_COLLECTION), orderBy('createdAt', 'desc'))
  const snap = await getDocs(q)
  return snap.docs.map(d => ({ id: d.id, ...d.data() } as BlogPost))
}

export async function getBlogPost(id: string): Promise<BlogPost | null> {
  const snap = await getDoc(doc(db, BLOG_COLLECTION, id))
  if (!snap.exists()) return null
  return { id: snap.id, ...snap.data() } as BlogPost
}

export { db }
