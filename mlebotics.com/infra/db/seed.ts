import { PrismaClient } from '@prisma/client'

const prisma = new PrismaClient()

async function main() {
  // ── User ──────────────────────────────────────────────────────────────────
  const user = await prisma.user.upsert({
    where: { email: 'eddie@mlebotics.com' },
    update: {},
    create: {
      id: 'mock-user-1',
      email: 'eddie@mlebotics.com',
      name: 'Eddie Chongtham',
      avatarUrl: null,
    },
  })

  // ── Organization ──────────────────────────────────────────────────────────
  const org = await prisma.organization.upsert({
    where: { slug: 'mlebotics' },
    update: {},
    create: {
      id: 'mock-org-1',
      name: 'MLEbotics',
      slug: 'mlebotics',
      avatarUrl: null,
    },
  })

  // ── Membership ────────────────────────────────────────────────────────────
  await prisma.membership.upsert({
    where: {
      userId_organizationId: {
        userId: user.id,
        organizationId: org.id,
      },
    },
    update: {},
    create: {
      userId: user.id,
      organizationId: org.id,
      role: 'OWNER',
    },
  })

  console.log(`✅  Seeded: user="${user.email}" org="${org.slug}"`)
}

main()
  .catch((e) => {
    console.error('Seed failed:', e)
    process.exit(1)
  })
  .finally(() => prisma.$disconnect())
