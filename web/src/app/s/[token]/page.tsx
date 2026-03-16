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
import PeopleOutlineIcon from '@mui/icons-material/PeopleOutline';
import ArchiveOutlinedIcon from '@mui/icons-material/ArchiveOutlined';
import { createSupabaseClient } from '@/lib/supabase';
import ExpenseAccordion from './ExpenseAccordion';

interface Props {
  params: Promise<{ token: string }>;
}

interface ShareLink { group_id: string; expires_at: string }
interface Group { id: string; name: string; type: string; currency: string; status: string }
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

const GROUP_TYPE_LABELS: Record<string, string> = {
  roommate: '合租',
  travel: '旅行',
  event: '活動',
  other: '其他',
};

function memberName(m: Member): string {
  return m.profiles?.display_name || m.profiles?.email || '未知成員';
}

function initials(name: string): string {
  return name.slice(0, 1).toUpperCase();
}

const AVATAR_COLORS = [
  '#6750A4', '#B5838D', '#3D5A80', '#81B29A',
  '#E07A5F', '#4A7C59', '#7B6D8D', '#C17817',
];

function avatarColor(userId: string): string {
  let hash = 0;
  for (let i = 0; i < userId.length; i++) hash = userId.charCodeAt(i) + ((hash << 5) - hash);
  return AVATAR_COLORS[Math.abs(hash) % AVATAR_COLORS.length];
}

function formatAmount(amount: number, currency: string): string {
  return `${currency} ${Math.abs(amount).toLocaleString('zh-TW', {
    minimumFractionDigits: 0,
    maximumFractionDigits: 0,
  })}`;
}

export default async function SharePage({ params }: Props) {
  const { token } = await params;
  const supabase = createSupabaseClient(token);

  const { data: shareLink } = await supabase
    .from('share_links')
    .select('group_id, expires_at')
    .eq('token', token)
    .gt('expires_at', new Date().toISOString())
    .maybeSingle();

  if (!shareLink) notFound();

  const groupId = (shareLink as ShareLink).group_id;

  const [{ data: group }, { data: membersRaw }, { data: expensesRaw }] = await Promise.all([
    supabase.from('groups').select('id, name, type, currency, status').eq('id', groupId).single(),
    supabase.from('group_members').select('user_id, profiles(display_name, email)').eq('group_id', groupId),
    supabase
      .from('expenses')
      .select('id, description, amount, paid_by, expense_date, category, splits:expense_splits(user_id, amount)')
      .eq('group_id', groupId)
      .order('expense_date', { ascending: false }),
  ]);

  if (!group) notFound();
  const g = group as Group;
  const members: Member[] = (membersRaw ?? []) as unknown as Member[];
  const expenses: Expense[] = (expensesRaw ?? []) as unknown as Expense[];

  // Compute net balances
  const memberMap = new Map<string, string>(members.map((m) => [m.user_id, memberName(m)]));
  const balances = new Map<string, number>();
  members.forEach((m) => balances.set(m.user_id, 0));
  for (const exp of expenses) {
    balances.set(exp.paid_by, (balances.get(exp.paid_by) ?? 0) + exp.amount);
    for (const split of exp.splits) {
      balances.set(split.user_id, (balances.get(split.user_id) ?? 0) - split.amount);
    }
  }

  const totalExpenses = expenses.reduce((s, e) => s + e.amount, 0);
  const isArchived = g.status === 'archived';

  // memberMap as plain object for client component
  const memberMapObj = Object.fromEntries(memberMap);

  return (
    <Box sx={{ minHeight: '100vh', bgcolor: '#F6F4FB', pb: 6 }}>
      {/* Header */}
      <Box
        sx={{
          background: 'linear-gradient(135deg, #6750A4 0%, #8B74C2 100%)',
          color: 'white',
          pt: 4,
          pb: 5,
          px: 2,
        }}
      >
        <Container maxWidth="sm">
          <Typography variant="caption" sx={{ opacity: 0.75, letterSpacing: 1 }}>
            OkaeriSplit
          </Typography>
          <Typography variant="h5" fontWeight="bold" sx={{ mt: 0.5, mb: 1.5 }}>
            {g.name}
          </Typography>
          <Stack direction="row" spacing={1} flexWrap="wrap" useFlexGap>
            <Chip
              label={GROUP_TYPE_LABELS[g.type] ?? g.type}
              size="small"
              sx={{ bgcolor: 'rgba(255,255,255,0.15)', color: 'white', fontWeight: 500 }}
            />
            <Chip
              label={g.currency}
              size="small"
              sx={{ bgcolor: 'rgba(255,255,255,0.15)', color: 'white', fontWeight: 500 }}
            />
            {isArchived && (
              <Chip
                icon={<ArchiveOutlinedIcon sx={{ fontSize: '14px !important', color: 'white !important' }} />}
                label="已封存"
                size="small"
                sx={{ bgcolor: 'rgba(255,255,255,0.15)', color: 'white', fontWeight: 500 }}
              />
            )}
          </Stack>
        </Container>
      </Box>

      {/* Summary strip (overlaps header) */}
      <Container maxWidth="sm" sx={{ mt: -2 }}>
        <Card sx={{ borderRadius: 3, overflow: 'hidden' }}>
          <Box sx={{ display: 'flex' }}>
            <Box sx={{ flex: 1, py: 2, textAlign: 'center' }}>
              <Typography variant="caption" color="text.secondary" display="block">
                總支出
              </Typography>
              <Typography variant="subtitle1" fontWeight={700} color="primary.main">
                {formatAmount(totalExpenses, g.currency)}
              </Typography>
            </Box>
            <Divider orientation="vertical" flexItem />
            <Box sx={{ flex: 1, py: 2, textAlign: 'center' }}>
              <Typography variant="caption" color="text.secondary" display="block">
                成員
              </Typography>
              <Typography variant="subtitle1" fontWeight={700} color="primary.main">
                {members.length} 人
              </Typography>
            </Box>
            <Divider orientation="vertical" flexItem />
            <Box sx={{ flex: 1, py: 2, textAlign: 'center' }}>
              <Typography variant="caption" color="text.secondary" display="block">
                消費筆數
              </Typography>
              <Typography variant="subtitle1" fontWeight={700} color="primary.main">
                {expenses.length} 筆
              </Typography>
            </Box>
          </Box>
        </Card>

        {/* Member balances */}
        <Stack direction="row" alignItems="center" spacing={1} sx={{ mt: 3, mb: 1.5 }}>
          <AccountBalanceWalletOutlinedIcon fontSize="small" color="action" />
          <Typography variant="subtitle1" fontWeight={600}>
            成員帳務
          </Typography>
        </Stack>
        <Card sx={{ borderRadius: 3 }}>
          <CardContent sx={{ p: 0, '&:last-child': { pb: 0 } }}>
            {members.length === 0 ? (
              <Box sx={{ py: 3, textAlign: 'center' }}>
                <PeopleOutlineIcon sx={{ color: 'text.disabled', mb: 1 }} />
                <Typography variant="body2" color="text.secondary">
                  尚無成員
                </Typography>
              </Box>
            ) : (
              members.map((member, idx) => {
                const net = balances.get(member.user_id) ?? 0;
                const isSettled = Math.abs(net) < 0.01;
                const name = memberName(member);
                const color = avatarColor(member.user_id);
                return (
                  <Box key={member.user_id}>
                    {idx > 0 && <Divider />}
                    <Box sx={{ display: 'flex', alignItems: 'center', px: 2, py: 1.5, gap: 1.5 }}>
                      {/* Avatar */}
                      <Box
                        sx={{
                          width: 36,
                          height: 36,
                          borderRadius: '50%',
                          bgcolor: color,
                          display: 'flex',
                          alignItems: 'center',
                          justifyContent: 'center',
                          color: 'white',
                          fontWeight: 700,
                          fontSize: 14,
                          flexShrink: 0,
                        }}
                      >
                        {initials(name)}
                      </Box>
                      <Typography variant="body1" sx={{ flex: 1 }}>
                        {name}
                      </Typography>
                      {isSettled ? (
                        <Stack direction="row" alignItems="center" spacing={0.5}>
                          <CheckCircleOutlineIcon fontSize="small" color="success" />
                          <Typography variant="body2" color="success.main" fontWeight={500}>
                            已結清
                          </Typography>
                        </Stack>
                      ) : (
                        <Box sx={{ textAlign: 'right' }}>
                          <Typography
                            variant="body2"
                            fontWeight={700}
                            color={net > 0 ? 'success.main' : 'error.main'}
                          >
                            {net > 0 ? '+' : ''}{formatAmount(net, g.currency)}
                          </Typography>
                          <Typography variant="caption" color="text.secondary">
                            {net > 0 ? '應收' : '應付'}
                          </Typography>
                        </Box>
                      )}
                    </Box>
                  </Box>
                );
              })
            )}
          </CardContent>
        </Card>

        {/* Expense list */}
        <Stack direction="row" alignItems="center" spacing={1} sx={{ mt: 3, mb: 1.5 }}>
          <ReceiptLongOutlinedIcon fontSize="small" color="action" />
          <Typography variant="subtitle1" fontWeight={600}>
            消費紀錄
          </Typography>
          {expenses.length > 0 && (
            <Typography variant="caption" color="text.secondary">
              （點擊查看明細）
            </Typography>
          )}
        </Stack>
        <Card sx={{ borderRadius: 3 }}>
          <CardContent sx={{ p: 0, '&:last-child': { pb: 0 } }}>
            <ExpenseAccordion
              expenses={expenses}
              memberMap={memberMapObj}
              currency={g.currency}
            />
          </CardContent>
        </Card>

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
