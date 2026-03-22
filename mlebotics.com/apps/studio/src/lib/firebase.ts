import { initializeApp, getApps } from 'firebase/app'
import {
  getFirestore,
  enableIndexedDbPersistence,
  collection,
  addDoc,
  query,
  orderBy,
  limit,
  onSnapshot,
  serverTimestamp,
  type Timestamp,
} from 'firebase/firestore'

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
