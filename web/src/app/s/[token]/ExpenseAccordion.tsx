'use client';

import { useState } from 'react';
import {
  Box,
  Typography,
  Divider,
  Collapse,
  Chip,
  Stack,
} from '@mui/material';
import RestaurantIcon from '@mui/icons-material/Restaurant';
import DirectionsCarIcon from '@mui/icons-material/DirectionsCar';
import HotelIcon from '@mui/icons-material/Hotel';
import MovieIcon from '@mui/icons-material/Movie';
import ShoppingBagIcon from '@mui/icons-material/ShoppingBag';
import CategoryIcon from '@mui/icons-material/Category';
import ExpandMoreIcon from '@mui/icons-material/ExpandMore';
import ExpandLessIcon from '@mui/icons-material/ExpandLess';
import PersonOutlineIcon from '@mui/icons-material/PersonOutline';
import CalendarTodayOutlinedIcon from '@mui/icons-material/CalendarTodayOutlined';
import PeopleAltOutlinedIcon from '@mui/icons-material/PeopleAltOutlined';

const CATEGORY_LABELS: Record<string, string> = {
  food: '餐飲',
  transport: '交通',
  accommodation: '住宿',
  entertainment: '娛樂',
  daily_necessities: '日用品',
  other: '其他',
};

const CATEGORY_ICONS: Record<string, React.ReactNode> = {
  food: <RestaurantIcon fontSize="small" />,
  transport: <DirectionsCarIcon fontSize="small" />,
  accommodation: <HotelIcon fontSize="small" />,
  entertainment: <MovieIcon fontSize="small" />,
  daily_necessities: <ShoppingBagIcon fontSize="small" />,
  other: <CategoryIcon fontSize="small" />,
};

interface Split {
  user_id: string;
  amount: number;
}

interface ExpenseItem {
  id: string;
  description: string;
  amount: number;
  currency: string;
  paid_by: string;
  expense_date: string;
  category: string | null;
  splits: Split[];
}

interface Props {
  expenses: ExpenseItem[];
  memberMap: Record<string, string>;
  currency: string;
}

function formatDate(iso: string): string {
  return new Intl.DateTimeFormat('zh-TW', {
    year: 'numeric',
    month: 'long',
    day: 'numeric',
  }).format(new Date(iso));
}

function formatAmount(amount: number, currency: string): string {
  return `${currency} ${Math.abs(amount).toLocaleString('zh-TW', {
    minimumFractionDigits: 0,
    maximumFractionDigits: 0,
  })}`;
}

export default function ExpenseAccordion({ expenses, memberMap, currency }: Props) {
  const [openId, setOpenId] = useState<string | null>(null);

  if (expenses.length === 0) {
    return (
      <Box sx={{ py: 4, textAlign: 'center' }}>
        <Typography variant="body2" color="text.secondary">
          尚無消費紀錄
        </Typography>
      </Box>
    );
  }

  return (
    <>
      {expenses.map((exp, idx) => {
        const isOpen = openId === exp.id;
        const category = exp.category ?? 'other';
        const categoryLabel = CATEGORY_LABELS[category] ?? '其他';
        const categoryIcon = CATEGORY_ICONS[category] ?? <CategoryIcon fontSize="small" />;
        const payerName = memberMap[exp.paid_by] ?? '未知';
        const shortDate = new Intl.DateTimeFormat('zh-TW', {
          month: 'short',
          day: 'numeric',
        }).format(new Date(exp.expense_date));

        return (
          <Box key={exp.id}>
            {idx > 0 && <Divider />}
            <Box
              onClick={() => setOpenId(isOpen ? null : exp.id)}
              sx={{
                px: 2,
                py: 1.5,
                cursor: 'pointer',
                '&:hover': { bgcolor: 'action.hover' },
                transition: 'background-color 0.15s',
              }}
            >
              <Box sx={{ display: 'flex', alignItems: 'center', gap: 1.5 }}>
                {/* Category icon */}
                <Box
                  sx={{
                    width: 40,
                    height: 40,
                    borderRadius: '50%',
                    bgcolor: 'primary.50',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    color: 'primary.main',
                    flexShrink: 0,
                  }}
                >
                  {categoryIcon}
                </Box>

                {/* Description + meta */}
                <Box sx={{ flex: 1, minWidth: 0 }}>
                  <Typography
                    variant="body1"
                    fontWeight={500}
                    noWrap
                  >
                    {exp.description}
                  </Typography>
                  <Typography variant="caption" color="text.secondary">
                    {payerName} · {shortDate}
                  </Typography>
                </Box>

                {/* Amount + expand icon */}
                <Stack alignItems="flex-end" spacing={0.25} sx={{ flexShrink: 0 }}>
                  <Typography variant="body2" fontWeight={600}>
                    {formatAmount(exp.amount, exp.currency)}
                  </Typography>
                  <Box sx={{ color: 'text.disabled', display: 'flex' }}>
                    {isOpen ? (
                      <ExpandLessIcon sx={{ fontSize: 16 }} />
                    ) : (
                      <ExpandMoreIcon sx={{ fontSize: 16 }} />
                    )}
                  </Box>
                </Stack>
              </Box>
            </Box>

            {/* Expanded detail */}
            <Collapse in={isOpen} unmountOnExit>
              <Box
                sx={{
                  px: 2,
                  pb: 2,
                  bgcolor: 'grey.50',
                  borderTop: '1px solid',
                  borderColor: 'divider',
                }}
              >
                {/* Detail rows */}
                <Stack spacing={1.5} sx={{ pt: 1.5 }}>
                  <Stack direction="row" spacing={1} alignItems="center">
                    <CategoryIcon sx={{ fontSize: 16, color: 'text.secondary' }} />
                    <Typography variant="body2" color="text.secondary" sx={{ width: 48 }}>
                      分類
                    </Typography>
                    <Chip label={categoryLabel} size="small" variant="outlined" />
                  </Stack>

                  <Stack direction="row" spacing={1} alignItems="center">
                    <PersonOutlineIcon sx={{ fontSize: 16, color: 'text.secondary' }} />
                    <Typography variant="body2" color="text.secondary" sx={{ width: 48 }}>
                      付款人
                    </Typography>
                    <Typography variant="body2">{payerName}</Typography>
                  </Stack>

                  <Stack direction="row" spacing={1} alignItems="center">
                    <CalendarTodayOutlinedIcon sx={{ fontSize: 16, color: 'text.secondary' }} />
                    <Typography variant="body2" color="text.secondary" sx={{ width: 48 }}>
                      日期
                    </Typography>
                    <Typography variant="body2">{formatDate(exp.expense_date)}</Typography>
                  </Stack>

                  {exp.splits.length > 0 && (
                    <>
                      <Divider sx={{ my: 0.5 }} />
                      <Stack direction="row" spacing={1} alignItems="flex-start">
                        <PeopleAltOutlinedIcon sx={{ fontSize: 16, color: 'text.secondary', mt: 0.3 }} />
                        <Box sx={{ flex: 1 }}>
                          <Typography variant="body2" color="text.secondary" sx={{ mb: 1 }}>
                            分帳明細
                          </Typography>
                          <Stack spacing={0.75}>
                            {exp.splits.map((split) => (
                              <Box
                                key={split.user_id}
                                sx={{ display: 'flex', justifyContent: 'space-between' }}
                              >
                                <Typography variant="body2">
                                  {memberMap[split.user_id] ?? '未知'}
                                </Typography>
                                <Typography variant="body2" fontWeight={500}>
                                  {formatAmount(split.amount, exp.currency)}
                                </Typography>
                              </Box>
                            ))}
                          </Stack>
                        </Box>
                      </Stack>
                    </>
                  )}
                </Stack>
              </Box>
            </Collapse>
          </Box>
        );
      })}
    </>
  );
}
