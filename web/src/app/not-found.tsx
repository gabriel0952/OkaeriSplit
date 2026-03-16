import { Box, Container, Typography } from '@mui/material';
import LinkOffIcon from '@mui/icons-material/LinkOff';

export default function NotFound() {
  return (
    <Box
      sx={{
        minHeight: '100vh',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        bgcolor: 'grey.50',
      }}
    >
      <Container maxWidth="xs" sx={{ textAlign: 'center', py: 6 }}>
        <LinkOffIcon sx={{ fontSize: 64, color: 'text.disabled', mb: 2 }} />
        <Typography variant="h6" fontWeight={600} gutterBottom>
          連結無效或已過期
        </Typography>
        <Typography variant="body2" color="text.secondary">
          此分享連結不存在或已超過有效期限。
          <br />
          請向群組成員索取新的分享連結。
        </Typography>
      </Container>
    </Box>
  );
}
