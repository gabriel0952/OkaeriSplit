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
import Image from 'next/image';
import AccountBalanceWalletOutlinedIcon from '@mui/icons-material/AccountBalanceWalletOutlined';
import ReceiptLongOutlinedIcon from '@mui/icons-material/ReceiptLongOutlined';
import CheckCircleOutlineIcon from '@mui/icons-material/CheckCircleOutline';
import PeopleOutlineIcon from '@mui/icons-material/PeopleOutline';
import ArchiveOutlinedIcon from '@mui/icons-material/ArchiveOutlined';
import SwapHorizIcon from '@mui/icons-material/SwapHoriz';
import ArrowRightAltIcon from '@mui/icons-material/ArrowRightAlt';
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
interface Settlement {
  from_user: string;
  to_user: string;
  amount: number;
}
interface SimplifiedDebt {
  fromUserId: string;
  toUserId: string;
  amount: number;
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
  '#ED9153', '#B5838D', '#3D5A80', '#81B29A',
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

/** Greedy minimum-transfer debt simplification (mirrors Flutter DebtSimplifier) */
function simplifyDebts(balances: Map<string, number>): SimplifiedDebt[] {
  const threshold = 0.005;
  const debtors: { id: string; amount: number }[] = [];
  const creditors: { id: string; amount: number }[] = [];

  for (const [id, balance] of balances) {
    if (balance < -threshold) debtors.push({ id, amount: -balance });
    else if (balance > threshold) creditors.push({ id, amount: balance });
  }

  // Sort descending so largest amounts are matched first
  debtors.sort((a, b) => b.amount - a.amount);
  creditors.sort((a, b) => b.amount - a.amount);

  const result: SimplifiedDebt[] = [];
  let i = 0, j = 0;
  while (i < debtors.length && j < creditors.length) {
    const transfer = Math.min(debtors[i].amount, creditors[j].amount);
    if (transfer > threshold) {
      result.push({
        fromUserId: debtors[i].id,
        toUserId: creditors[j].id,
        amount: Math.round(transfer * 100) / 100,
      });
    }
    debtors[i].amount -= transfer;
    creditors[j].amount -= transfer;
    if (debtors[i].amount < threshold) i++;
    if (creditors[j].amount < threshold) j++;
  }

  return result;
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

  const [{ data: group }, { data: membersRaw }, { data: expensesRaw }, { data: settlementsRaw }] =
    await Promise.all([
      supabase.from('groups').select('id, name, type, currency, status').eq('id', groupId).single(),
      supabase.from('group_members').select('user_id, profiles(display_name, email)').eq('group_id', groupId),
      supabase
        .from('expenses')
        .select('id, description, amount, paid_by, expense_date, category, splits:expense_splits(user_id, amount)')
        .eq('group_id', groupId)
        .order('expense_date', { ascending: false }),
      supabase
        .from('settlements')
        .select('from_user, to_user, amount')
        .eq('group_id', groupId),
    ]);

  if (!group) notFound();
  const g = group as Group;
  const members: Member[] = (membersRaw ?? []) as unknown as Member[];
  const expenses: Expense[] = (expensesRaw ?? []) as unknown as Expense[];
  const settlements: Settlement[] = (settlementsRaw ?? []) as unknown as Settlement[];

  // Compute net balances (expenses + settlements)
  const memberMap = new Map<string, string>(members.map((m) => [m.user_id, memberName(m)]));
  const balances = new Map<string, number>();
  members.forEach((m) => balances.set(m.user_id, 0));

  for (const exp of expenses) {
    balances.set(exp.paid_by, (balances.get(exp.paid_by) ?? 0) + exp.amount);
    for (const split of exp.splits) {
      balances.set(split.user_id, (balances.get(split.user_id) ?? 0) - split.amount);
    }
  }
  // Adjust for recorded settlements: payer balance increases (they paid out), receiver decreases
  for (const s of settlements) {
    balances.set(s.from_user, (balances.get(s.from_user) ?? 0) + s.amount);
    balances.set(s.to_user, (balances.get(s.to_user) ?? 0) - s.amount);
  }

  const simplifiedDebts = simplifyDebts(balances);
  const totalExpenses = expenses.reduce((s, e) => s + e.amount, 0);
  const isArchived = g.status === 'archived';

  // memberMap as plain object for client component
  const memberMapObj = Object.fromEntries(memberMap);

  return (
    <Box sx={{ minHeight: '100vh', bgcolor: '#FDF8F4', pb: 6 }}>
      {/* Header */}
      <Box
        sx={{
          background: 'linear-gradient(135deg, #ED9153 0%, #E07430 100%)',
          color: 'white',
          pt: 4,
          pb: 5,
          px: 2,
        }}
      >
        <Container maxWidth="sm">
          <Stack direction="row" alignItems="center" spacing={1} sx={{ mb: 1.5 }}>
            <Image
              src="/logo.png"
              alt="OkaeriSplit"
              width={28}
              height={28}
              style={{ borderRadius: 6 }}
            />
            <Typography variant="caption" sx={{ opacity: 0.9, letterSpacing: 1, fontWeight: 600 }}>
              OkaeriSplit
            </Typography>
          </Stack>
          <Typography variant="h5" fontWeight="bold" sx={{ mb: 1.5 }}>
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

        {/* Simplified debts */}
        <Stack direction="row" alignItems="center" spacing={1} sx={{ mt: 3, mb: 1.5 }}>
          <SwapHorizIcon fontSize="small" color="action" />
          <Typography variant="subtitle1" fontWeight={600}>
            建議轉帳
          </Typography>
          {simplifiedDebts.length > 0 && (
            <Typography variant="caption" color="text.secondary">
              最少 {simplifiedDebts.length} 筆完成結算
            </Typography>
          )}
        </Stack>
        <Card sx={{ borderRadius: 3 }}>
          <CardContent sx={{ p: 0, '&:last-child': { pb: 0 } }}>
            {simplifiedDebts.length === 0 ? (
              <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 1, py: 2.5 }}>
                <CheckCircleOutlineIcon fontSize="small" color="success" />
                <Typography variant="body2" color="success.main" fontWeight={500}>
                  所有帳務已結清
                </Typography>
              </Box>
            ) : (
              simplifiedDebts.map((debt, idx) => {
                const fromName = memberMap.get(debt.fromUserId) ?? '未知';
                const toName = memberMap.get(debt.toUserId) ?? '未知';
                const fromColor = avatarColor(debt.fromUserId);
                const toColor = avatarColor(debt.toUserId);
                return (
                  <Box key={idx}>
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
                      {/* From avatar + name */}
                      <Box
                        sx={{
                          width: 32,
                          height: 32,
                          borderRadius: '50%',
                          bgcolor: fromColor,
                          display: 'flex',
                          alignItems: 'center',
                          justifyContent: 'center',
                          color: 'white',
                          fontWeight: 700,
                          fontSize: 13,
                          flexShrink: 0,
                        }}
                      >
                        {initials(fromName)}
                      </Box>
                      <Typography variant="body2" fontWeight={500} noWrap sx={{ maxWidth: 72 }}>
                        {fromName}
                      </Typography>

                      <ArrowRightAltIcon fontSize="small" sx={{ color: 'text.disabled', flexShrink: 0 }} />

                      {/* To avatar + name */}
                      <Box
                        sx={{
                          width: 32,
                          height: 32,
                          borderRadius: '50%',
                          bgcolor: toColor,
                          display: 'flex',
                          alignItems: 'center',
                          justifyContent: 'center',
                          color: 'white',
                          fontWeight: 700,
                          fontSize: 13,
                          flexShrink: 0,
                        }}
                      >
                        {initials(toName)}
                      </Box>
                      <Typography variant="body2" fontWeight={500} noWrap sx={{ maxWidth: 72 }}>
                        {toName}
                      </Typography>

                      <Box sx={{ flex: 1 }} />

                      {/* Amount */}
                      <Typography variant="body2" fontWeight={700} color="error.main">
                        {formatAmount(debt.amount, g.currency)}
                      </Typography>
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
