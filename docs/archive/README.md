# 📦 Infrastructure Documentation Archive

Historical troubleshooting and fix documentation for Dentia infrastructure.

---

## 📋 Purpose

This folder contains documentation for infrastructure issues that have been resolved:

- **Bastion Host**: Configuration and connectivity fixes
- **Backend URL**: Backend URL parameter fixes
- **Quick Fixes**: Summary of various infrastructure fixes

---

## 🗂️ Archive Index

### Bastion Host

| Document | Description |
|----------|-------------|
| [BASTION_FIX_QUICK_START.md](BASTION_FIX_QUICK_START.md) | Quick start guide for fixing bastion issues |
| [BASTION_IMPROVEMENTS.md](BASTION_IMPROVEMENTS.md) | Bastion host improvements and configuration |

### Backend Configuration

| Document | Description |
|----------|-------------|
| [BACKEND_URL_FIX.md](BACKEND_URL_FIX.md) | Backend URL parameter configuration fix |

### General Fixes

| Document | Description |
|----------|-------------|
| [QUICK_FIX_SUMMARY.md](QUICK_FIX_SUMMARY.md) | Summary of quick infrastructure fixes |

---

## 🔍 When to Use Archive Docs

### Use These When:
- 🐛 **Encountering similar issues** - Check if it was solved before
- 📚 **Understanding history** - See why certain configurations exist
- 🔄 **Repeating a fix** - Reference previous solutions
- 🎓 **Onboarding** - Understand infrastructure evolution

### Don't Use These For:
- ❌ **Current operations** - Use active documentation in parent `docs/`
- ❌ **New deployments** - Use current Terraform configurations
- ❌ **Standard procedures** - Use utility scripts and main README

---

## 📊 Archive Stats

- **Total Archived Documents**: 4
- **Categories**: 3 (Bastion, Backend, General)
- **Topics Covered**:
  - Bastion host connectivity
  - SSM Session Manager setup
  - Backend URL configuration
  - Infrastructure quick fixes

---

## 🔎 Common Issues Covered

### Bastion Host Issues

**Problem**: Can't connect to bastion via SSM  
**Solution**: See [BASTION_FIX_QUICK_START.md](BASTION_FIX_QUICK_START.md)

**Problem**: Bastion host needs improvements  
**Solution**: See [BASTION_IMPROVEMENTS.md](BASTION_IMPROVEMENTS.md)

### Backend Configuration

**Problem**: Backend URL not properly configured  
**Solution**: See [BACKEND_URL_FIX.md](BACKEND_URL_FIX.md)

---

## 🛠️ Current Solutions

For current infrastructure issues, use these tools:

### Diagnostic Scripts

```bash
# Diagnose bastion connectivity
./diagnose-bastion.sh

# Fix SSM connectivity
./fix-bastion-ssm.sh

# Connect to database
./connect-to-database.sh
```

### Terraform Commands

```bash
# Check infrastructure state
terraform state list

# View specific resource
terraform state show aws_instance.bastion

# Re-apply configuration
terraform apply
```

---

## 📝 Adding to Archive

When archiving new infrastructure documentation:

1. **Name clearly**: `COMPONENT_ISSUE_FIX.md`
2. **Add to this README**: Update appropriate category
3. **Date the document**: Add "Archived: YYYY-MM-DD" at top
4. **Link from main docs**: If replacing active documentation

---

## ⚠️ Important Notes

### These Documents Are:
- ✅ Historical records of fixes
- ✅ Useful for troubleshooting similar issues
- ✅ Context for current configurations
- ✅ Learning resources

### These Documents Are NOT:
- ❌ Current operational procedures
- ❌ Active deployment guides
- ❌ Up-to-date best practices
- ❌ Current Terraform configurations

**Always check current Terraform code and scripts first!**

---

## 🔗 Related Documentation

- **Active Docs**: [../README.md](../README.md)
- **Main Infrastructure**: [../../README.md](../../README.md)
- **Terraform Files**: `../../infra/ecs/`
- **Scripts**: `../../infra/scripts/`

---

## 📊 Issue Categories

### By Component

```
Bastion Host       (2 docs)
Backend Config     (1 doc)
General Fixes      (1 doc)
```

### By Type

```
Configuration      (2 docs)
Connectivity       (1 doc)
Quick Fixes        (1 doc)
```

---

## 🔍 Search Tips

### Find by Component

```bash
# Bastion-related docs
ls -1 *BASTION*

# Backend configuration
ls -1 *BACKEND*

# All fix docs
ls -1 *FIX*
```

### Search Content

```bash
# Find mentions of SSM
grep -r "SSM" .

# Find terraform commands
grep -r "terraform" .
```

---

## 📈 Archive Timeline

Historical issues documented:
1. **Bastion Host Setup** - Initial bastion configuration
2. **SSM Connectivity** - Session Manager fixes
3. **Backend URL** - Parameter store configuration
4. **Quick Fixes** - Various infrastructure improvements

---

## 🎯 Quick Reference

### Most Common Issues

1. **Bastion Connectivity**
   - Document: BASTION_FIX_QUICK_START.md
   - Current Tool: `./diagnose-bastion.sh`

2. **Database Access**
   - Document: BASTION_IMPROVEMENTS.md
   - Current Tool: `./connect-to-database.sh`

3. **Backend Configuration**
   - Document: BACKEND_URL_FIX.md
   - Current Tool: `./add-backend-url-param.sh`

---

## 🔐 Security Note

These documents may reference:
- Security group IDs
- Instance IDs
- Configuration values

**Always verify current values** in AWS Console or Terraform state before using historical references.

---

## 📞 Getting Help

### If You're Troubleshooting:
1. ✅ Check these archived docs for similar issues
2. ✅ Use diagnostic scripts (`./diagnose-*.sh`)
3. ✅ Review Terraform state
4. ✅ Check CloudWatch logs
5. ✅ Consult AWS documentation

### If You're Deploying:
1. ❌ Don't rely solely on archived docs
2. ✅ Use current Terraform configurations
3. ✅ Follow main README procedures
4. ✅ Test in dev environment first

---

**Archive Created**: November 14, 2024  
**Total Documents**: 4  
**Status**: Organized and indexed

