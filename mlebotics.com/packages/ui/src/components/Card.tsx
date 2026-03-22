import * as React from 'react'

interface CardProps { className?: string; children: React.ReactNode }

export function Card({ className = '', children }: CardProps) {
  return (
    <div className={`bg-gray-900 border border-gray-800 rounded-xl ${className}`}>
      {children}
    </div>
  )
}

export function CardHeader({ className = '', children }: CardProps) {
  return <div className={`px-5 py-4 border-b border-gray-800 ${className}`}>{children}</div>
}

export function CardContent({ className = '', children }: CardProps) {
  return <div className={`px-5 py-4 ${className}`}>{children}</div>
}

export function CardFooter({ className = '', children }: CardProps) {
  return (
    <div className={`px-5 py-3 border-t border-gray-800 bg-gray-950/40 rounded-b-xl ${className}`}>
      {children}
    </div>
  )
}
