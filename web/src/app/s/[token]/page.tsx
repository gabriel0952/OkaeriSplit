import { notFound } from 'next/navigation';
import {
  Box,
  Container,
  Typography,
  Card,
  CardContent,
  Chip,
  Divider,
  Stack,
} from '@mui/material';
import AccountBalanceWalletOutlinedIcon from '@mui/icons-material/AccountBalanceWalletOutlined';
import ReceiptLongOutlinedIcon from '@mui/icons-material/ReceiptLongOutlined';
import CheckCircleOutlineIcon from '@mui/icons-material/CheckCircleOutline';
import { createSupabaseClient } from '@/lib/supabase';

interface Props {
  params: Promise<{ token: string }>;
}

// ──────────────────────────────────────────────
// Data types
// ──────────────────────────────────────────────

interface ShareLink {
  group_id: string;
  expires_at: string;
}

interface Group {
  id: string;
  name: string;
  type: string;
  currency: string;
  status: string;
}

interface Member {
  user_id: string;
  profiles: { display_name: string | null; email: string | null } | null;
}

interface Expense {
  id: string;
  description: string;
  amount: number;
  paid_by: string;
  expense_date: string;
  category: string | null;
  splits: { user_id: string; amount: number }[];
}

// ──────────────────────────────────────────────
// Helpers
// ──────────────────────────────────────────────

function memberName(m: Member): string {
  return m.profiles?.display_name || m.profiles?.email || '未知成員';
}

function formatDate(iso: string): string {
  return new Intl.DateTimeFormat('zh-TW', { month: 'short', day: 'numeric' }).format(
    new Date(iso),
  );
}

function formatAmount(amount: number, currency: string): string {
  return `${currency} ${Math.abs(amount).toLocaleString('zh-TW', {
    minimumFractionDigits: 0,
    maximumFractionDigits: 0,
  })}`;
}

const CATEGORY_LABELS: Record<string, string> = {
  food: '餐飲',
  transport: '交通',
  accommodation: '住宿',
  entertainment: '娛樂',
  shopping: '購物',
  utilities: '生活費',
  other: '其他',
};

// ──────────────────────────────────────────────
// Page
// ──────────────────────────────────────────────

export default async function SharePage({ params }: Props) {
  const { token } = await params;
  const supabase = createSupabaseClient(token);

  // 4.2: Validate token
  const { data: shareLink } = await supabase
    .from('share_links')
    .select('group_id, expires_at')
    .eq('token', token)
    .gt('expires_at', new Date().toISOString())
    .maybeSingle();

  if (!shareLink) {
    notFound();
  }

  const groupId = (shareLink as ShareLink).group_id;

  // 4.3: Fetch group info
  const { data: group } = await supabase
    .from('groups')
    .select('id, name, type, currency, status')
    .eq('id', groupId)
    .single();

  if (!group) notFound();
  const g = group as Group;

  // 4.4: Fetch members
  const { data: membersRaw } = await supabase
    .from('group_members')
    .select('user_id, profiles(display_name, email)')
    .eq('group_id', groupId);

  const members: Member[] = (membersRaw ?? []) as unknown as Member[];

  // 4.5: Fetch expenses (descending)
  const { data: expensesRaw } = await supabase
    .from('expenses')
    .select('id, description, amount, paid_by, expense_date, category, splits:expense_splits(user_id, amount)')
    .eq('group_id', groupId)
    .order('expense_date', { ascending: false });

  const expenses: Expense[] = (expensesRaw ?? []) as unknown as Expense[];

  // 4.4: Compute net balances per member
  const memberMap = new Map<string, string>(
    members.map((m) => [m.user_id, memberName(m)]),
  );
  const balances = new Map<string, number>();
  members.forEach((m) => balances.set(m.user_id, 0));

  for (const exp of expenses) {
    // Payer gets credited the full amount
    balances.set(exp.paid_by, (balances.get(exp.paid_by) ?? 0) + exp.amount);
    // Each split member owes their share
    for (const split of exp.splits) {
      balances.set(split.user_id, (balances.get(split.user_id) ?? 0) - split.amount);
    }
  }

  const isArchived = g.status === 'archived';

  return (
    <Box sx={{ minHeight: '100vh', bgcolor: 'grey.50', pb: 6 }}>
      {/* Header */}
      <Box sx={{ bgcolor: 'primary.main', color: 'white', py: 3, px: 2 }}>
        <Container maxWidth="sm">
          <Typography variant="caption" sx={{ opacity: 0.8 }}>
            OkaeriSplit 分帳資訊
          </Typography>
          <Typography variant="h5" fontWeight="bold" sx={{ mt: 0.5 }}>
            {g.name}
          </Typography>
          <Stack direction="row" spacing={1} sx={{ mt: 1 }}>
            <Chip
              label={g.currency}
              size="small"
              sx={{ bgcolor: 'rgba(255,255,255,0.2)', color: 'white', fontSize: 12 }}
            />
            {isArchived && (
              <Chip
                label="已封存"
                size="small"
                sx={{ bgcolor: 'rgba(255,255,255,0.2)', color: 'white', fontSize: 12 }}
              />
            )}
          </Stack>
        </Container>
      </Box>

      <Container maxWidth="sm" sx={{ mt: 3 }}>
        {/* 4.6: Member balances */}
        <Stack direction="row" alignItems="center" spacing={1} sx={{ mb: 1.5 }}>
          <AccountBalanceWalletOutlinedIcon fontSize="small" color="action" />
          <Typography variant="subtitle1" fontWeight={600}>
            成員帳務
          </Typography>
        </Stack>
        <Card sx={{ mb: 3 }}>
          <CardContent sx={{ p: 0, '&:last-child': { pb: 0 } }}>
            {members.length === 0 ? (
              <Typography variant="body2" color="text.secondary" sx={{ p: 2 }}>
                尚無成員
              </Typography>
            ) : (
              members.map((member, idx) => {
                const net = balances.get(member.user_id) ?? 0;
                const isSettled = Math.abs(net) < 0.01;
                return (
                  <Box key={member.user_id}>
                    {idx > 0 && <Divider />}
                    <Box
                      sx={{
                        display: 'flex',
                        alignItems: 'center',
                        px: 2,
                        py: 1.5,
                        gap: 1,
                      }}
                    >
                      <Typography variant="body1" sx={{ flex: 1 }}>
                        {memberName(member)}
                      </Typography>
                      {isSettled ? (
                        <Stack direction="row" alignItems="center" spacing={0.5}>
                          <CheckCircleOutlineIcon fontSize="small" color="success" />
                          <Typography variant="body2" color="success.main">
                            已結清
                          </Typography>
                        </Stack>
                      ) : (
                        <Typography
                          variant="body2"
                          fontWeight={600}
                          color={net > 0 ? 'success.main' : 'error.main'}
                        >
                          {net > 0 ? '+' : ''}
                          {formatAmount(net, g.currency)}
                        </Typography>
                      )}
                    </Box>
                  </Box>
                );
              })
            )}
          </CardContent>
        </Card>

        {/* 4.7: Expense list */}
        <Stack direction="row" alignItems="center" spacing={1} sx={{ mb: 1.5 }}>
          <ReceiptLongOutlinedIcon fontSize="small" color="action" />
          <Typography variant="subtitle1" fontWeight={600}>
            消費紀錄
          </Typography>
        </Stack>
        {expenses.length === 0 ? (
          <Card>
            <CardContent>
              <Typography variant="body2" color="text.secondary" textAlign="center">
                尚無消費紀錄
              </Typography>
            </CardContent>
          </Card>
        ) : (
          <Card>
            <CardContent sx={{ p: 0, '&:last-child': { pb: 0 } }}>
              {expenses.map((exp, idx) => (
                <Box key={exp.id}>
                  {idx > 0 && <Divider />}
                  <Box sx={{ px: 2, py: 1.5 }}>
                    <Box sx={{ display: 'flex', alignItems: 'flex-start', gap: 1 }}>
                      <Box sx={{ flex: 1 }}>
                        <Typography variant="body1">{exp.description}</Typography>
                        <Typography variant="caption" color="text.secondary">
                          {memberMap.get(exp.paid_by) ?? '未知'} 付款 ·{' '}
                          {formatDate(exp.expense_date)}
                          {exp.category && exp.category !== 'other'
                            ? ` · ${CATEGORY_LABELS[exp.category] ?? exp.category}`
                            : ''}
                        </Typography>
                      </Box>
                      <Typography variant="body2" fontWeight={600}>
                        {formatAmount(exp.amount, g.currency)}
                      </Typography>
                    </Box>
                  </Box>
                </Box>
              ))}
            </CardContent>
          </Card>
        )}

        {/* Footer */}
        <Typography
          variant="caption"
          color="text.disabled"
          display="block"
          textAlign="center"
          sx={{ mt: 4 }}
        >
          由 OkaeriSplit 產生 · 資料僅供參考
        </Typography>
      </Container>
    </Box>
  );
}
